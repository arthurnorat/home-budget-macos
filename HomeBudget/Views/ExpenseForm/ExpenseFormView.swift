import SwiftUI

/// What the expense form was opened for.
enum ExpenseFormTarget: Identifiable {
    case new
    case edit(Expense)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let expense): return expense.id
        }
    }

    var expense: Expense? {
        switch self {
        case .new: return nil
        case .edit(let expense): return expense
        }
    }
}

/// Sheet to create an expense or edit an existing one.
struct ExpenseFormView: View {
    let viewModel: DashboardViewModel
    let editing: Expense?

    @Environment(\.dismiss) private var dismiss

    @State private var description: String
    @State private var amountText: String
    @State private var date: Date
    @State private var category: Category
    @State private var isSaving = false

    init(viewModel: DashboardViewModel, editing: Expense?) {
        self.viewModel = viewModel
        self.editing = editing
        // The fields start from the expense being edited, or from the defaults.
        _description = State(initialValue: editing?.description ?? "")
        _amountText = State(initialValue: editing.map { Formatters.amountText(fromCents: $0.amount) } ?? "")
        _date = State(initialValue: editing.flatMap { Formatters.date(fromISO: $0.date) } ?? viewModel.defaultExpenseDate)
        _category = State(initialValue: editing?.category ?? .variable)
    }

    // MARK: Validation

    private var trimmedDescription: String {
        description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var amountInCents: Int? {
        guard let cents = Formatters.parseAmountToCents(amountText), cents > 0 else { return nil }
        return cents
    }

    private var canSave: Bool {
        trimmedDescription.count >= 2 && amountInCents != nil && !isSaving
    }

    /// Shown only after the user typed something that is not a valid amount.
    private var amountHint: String? {
        guard !amountText.trimmingCharacters(in: .whitespaces).isEmpty, amountInCents == nil else { return nil }
        return "Digite um valor maior que zero, como 15,50."
    }

    // MARK: Body

    var body: some View {
        Form {
            Section(editing == nil ? "Novo gasto" : "Editar gasto") {
                fields
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(editing == nil ? "Adicionar" : "Salvar") {
                    Task { await save() }
                }
                .disabled(!canSave)
            }
        }
        .disabled(isSaving)
    }

    @ViewBuilder
    private var fields: some View {
        TextField("Descrição", text: $description, prompt: Text("Ex.: Supermercado"))

        TextField("Valor (R$)", text: $amountText, prompt: Text("0,00"))
        if let amountHint {
            Text(amountHint)
                .font(.callout)
                .foregroundStyle(.red)
        }

        DatePicker("Data", selection: $date, displayedComponents: .date)

        Picker("Categoria", selection: $category) {
            ForEach(Category.allCases) { category in
                Text(category.displayName).tag(category)
            }
        }
        .pickerStyle(.segmented)
    }

    private func save() async {
        guard let cents = amountInCents else { return }
        isSaving = true
        defer { isSaving = false }

        let request = ExpenseRequest(
            description: trimmedDescription,
            amount: cents,
            date: Formatters.isoDateString(from: date),
            category: category
        )
        // On failure the view model shows the error and the form stays open.
        if await viewModel.save(request, editing: editing) {
            dismiss()
        }
    }
}
