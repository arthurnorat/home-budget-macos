import Foundation
import Observation

/// Which expenses the table shows.
enum CategoryFilter: String, CaseIterable, Identifiable {
    case all
    case variable
    case fixed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "Todos"
        case .variable: return Category.variable.displayName
        case .fixed: return Category.fixed.displayName
        }
    }

    func matches(_ expense: Expense) -> Bool {
        switch self {
        case .all: return true
        case .variable: return expense.category == .variable
        case .fixed: return expense.category == .fixed
        }
    }
}

/// What a consolidation would create, shown to the user before confirming.
struct ConsolidationDraft: Equatable {
    let description: String
    let amount: Int
    let date: String
    let category: Category
    let count: Int
}

/// State and logic of the month dashboard: the selected month, its expenses
/// and income, the totals derived from them, and every action the user can take.
@Observable
final class DashboardViewModel {
    // MARK: State

    private(set) var month: String
    private(set) var expenses: [Expense] = []
    /// Income of the month, in cents. Zero means "not registered".
    private(set) var income: Int = 0

    var filter: CategoryFilter = .all
    var selection: Set<Expense.ID> = []

    private(set) var isLoading = false
    /// Set when the month could not be loaded; the screen shows it in place of the content.
    private(set) var loadError: String?
    /// Set when an action (save, delete, consolidate) failed; the screen shows it as an alert.
    var actionError: String?

    private let expenseService: ExpenseService
    private let incomeService: IncomeService

    init(
        month: String = Formatters.monthKey(),
        expenseService: ExpenseService = ExpenseService(),
        incomeService: IncomeService = IncomeService()
    ) {
        self.month = month
        self.expenseService = expenseService
        self.incomeService = incomeService
    }

    // MARK: Derived values

    var monthTitle: String {
        let title = Formatters.displayMonth(month)
        return title.prefix(1).uppercased() + title.dropFirst()
    }

    var isCurrentMonth: Bool { month == Formatters.monthKey() }

    var filteredExpenses: [Expense] {
        expenses.filter { filter.matches($0) }
    }

    var selectedExpenses: [Expense] {
        expenses.filter { selection.contains($0.id) }
    }

    var total: Int { Self.sum(expenses) }
    var totalFixed: Int { Self.sum(expenses.filter { $0.category == .fixed }) }
    var totalVariable: Int { Self.sum(expenses.filter { $0.category == .variable }) }

    /// 50/30/20 rule: 50% of the income for fixed expenses, 30% for variable, 20% to invest.
    var fixedTarget: Int { Self.share(of: income, percent: 50) }
    var variableTarget: Int { Self.share(of: income, percent: 30) }
    var investmentTarget: Int { Self.share(of: income, percent: 20) }

    var canConsolidate: Bool { selectedExpenses.count >= 2 }

    /// Same rule as the web: summed amount, most recent date,
    /// description and category of the first selected expense.
    var consolidationDraft: ConsolidationDraft? {
        let selected = selectedExpenses
        guard selected.count >= 2, let first = selected.first else { return nil }
        return ConsolidationDraft(
            description: first.description,
            amount: Self.sum(selected),
            date: selected.map(\.date).max() ?? first.date,
            category: first.category,
            count: selected.count
        )
    }

    // MARK: Month navigation

    func goToPreviousMonth() { show(Formatters.shiftMonth(month, by: -1)) }
    func goToNextMonth() { show(Formatters.shiftMonth(month, by: 1)) }
    func goToCurrentMonth() { show(Formatters.monthKey()) }

    /// Switches month and clears the old month's data, so the screen never
    /// shows one month's expenses under another month's title.
    /// The view reacts to the new `month` by calling `load()`.
    private func show(_ newMonth: String) {
        guard newMonth != month else { return }
        month = newMonth
        expenses = []
        income = 0
        selection = []
        loadError = nil
    }

    // MARK: Loading

    func load() async {
        let requestedMonth = month
        isLoading = true
        loadError = nil

        do {
            // Both requests run at the same time. `async let` forgets the typed
            // error, so each one travels as a `Result` and `get()` rethrows it typed.
            async let expensesResult = fetchExpenses(month: requestedMonth)
            async let incomeResult = fetchIncome(month: requestedMonth)
            let newExpenses = try await expensesResult.get()
            let newIncome = try await incomeResult.get()

            // The user may have moved to another month while this one was loading.
            guard requestedMonth == month else { return }
            expenses = Self.sorted(newExpenses)
            income = newIncome.amount
            selection = selection.intersection(Set(newExpenses.map(\.id)))
            isLoading = false
        } catch {
            guard requestedMonth == month else { return }
            isLoading = false
            // A cancelled request is not a failure: a newer load replaced it.
            if case .network(let urlError) = error, urlError.code == .cancelled { return }
            loadError = error.userMessage
        }
    }

    private func fetchExpenses(month: String) async -> Result<[Expense], AppError> {
        do {
            return .success(try await expenseService.fetchExpenses(month: month))
        } catch {
            return .failure(error)
        }
    }

    private func fetchIncome(month: String) async -> Result<MonthlyIncome, AppError> {
        do {
            return .success(try await incomeService.fetch(month: month))
        } catch {
            return .failure(error)
        }
    }

    // MARK: Expense actions

    /// Creates a new expense, or updates `editing` when it is given.
    /// Returns `true` on success, so the form knows it can close.
    func save(_ request: ExpenseRequest, editing: Expense? = nil) async -> Bool {
        do {
            let saved: Expense
            if let editing {
                saved = try await expenseService.update(id: editing.id, request)
            } else {
                saved = try await expenseService.create(request)
            }
            expenses.removeAll { $0.id == saved.id }
            // An expense dated in another month does not belong to this list.
            if saved.date.hasPrefix(month) {
                expenses = Self.sorted(expenses + [saved])
            } else {
                selection.remove(saved.id)
            }
            return true
        } catch {
            actionError = error.userMessage
            return false
        }
    }

    func delete(_ ids: Set<Expense.ID>) async {
        do {
            for id in ids {
                try await expenseService.delete(id: id)
                expenses.removeAll { $0.id == id }
                selection.remove(id)
            }
        } catch {
            actionError = error.userMessage
            // Some may have been deleted before the failure: show what the server has.
            await load()
        }
    }

    /// Replaces the selected expenses with a single one. The API has no
    /// endpoint for this: the new expense is created first and only then the
    /// originals are deleted, so a failure never loses money from the month.
    func consolidate(description: String) async -> Bool {
        guard let draft = consolidationDraft else { return false }
        let originals = selectedExpenses
        let request = ExpenseRequest(
            description: description,
            amount: draft.amount,
            date: draft.date,
            category: draft.category
        )

        do {
            let created = try await expenseService.create(request)
            expenses = Self.sorted(expenses + [created])
            for original in originals {
                try await expenseService.delete(id: original.id)
                expenses.removeAll { $0.id == original.id }
            }
            selection = []
            return true
        } catch {
            actionError = error.userMessage
            await load()
            return false
        }
    }

    // MARK: Income action

    func saveIncome(_ cents: Int) async -> Bool {
        do {
            let saved = try await incomeService.save(month: month, IncomeRequest(amount: cents))
            // Ignore the answer if the user already moved to another month.
            if saved.month == month {
                income = saved.amount
            }
            return true
        } catch {
            actionError = error.userMessage
            return false
        }
    }

    // MARK: Helpers

    private static func sum(_ expenses: [Expense]) -> Int {
        expenses.reduce(0) { $0 + $1.amount }
    }

    /// Integer percentage with rounding, so cents never pass through `Double`.
    private static func share(of amount: Int, percent: Int) -> Int {
        (amount * percent + 50) / 100
    }

    /// Most recent first; expenses of the same day keep creation order, newest first.
    private static func sorted(_ expenses: [Expense]) -> [Expense] {
        expenses.sorted {
            ($0.date, $0.createdAt) > ($1.date, $1.createdAt)
        }
    }
}
