import SwiftUI

/// The month's expenses: category filter, action buttons and a sortable table.
struct ExpenseTableView: View {
    @Bindable var viewModel: DashboardViewModel
    /// Called when the user asks to edit an expense; the parent presents the form.
    let onEdit: (Expense) -> Void

    /// How the table is sorted. Clicking a column header changes it.
    @State private var sortOrder = [KeyPathComparator(\Expense.date, order: .reverse)]
    /// Expenses waiting for the user to confirm the deletion.
    @State private var pendingDeletion: Set<Expense.ID> = []

    private var rows: [Expense] {
        viewModel.filteredExpenses.sorted(using: sortOrder)
    }

    var body: some View {
        VStack(spacing: 0) {
            actionBar
            Divider()
            table
        }
        .alert(deletionTitle, isPresented: isConfirmingDeletion) {
            Button("Excluir", role: .destructive) {
                let ids = pendingDeletion
                Task { await viewModel.delete(ids) }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta ação não pode ser desfeita.")
        }
    }

    // MARK: Action bar

    private var actionBar: some View {
        HStack(spacing: 12) {
            Picker("Categoria", selection: $viewModel.filter) {
                ForEach(CategoryFilter.allCases) { filter in
                    Text(filter.displayName).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            Text(summaryText)
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Editar", systemImage: "pencil") {
                if let expense = viewModel.selectedExpenses.first {
                    onEdit(expense)
                }
            }
            .disabled(viewModel.selection.count != 1)
            .help("Editar o gasto selecionado (duplo clique)")

            Button("Excluir", systemImage: "trash", role: .destructive) {
                pendingDeletion = viewModel.selection
            }
            .disabled(viewModel.selection.isEmpty)
            .help("Excluir os gastos selecionados (⌫)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var summaryText: String {
        let count = rows.count
        let total = Formatters.currency(fromCents: rows.reduce(0) { $0 + $1.amount })
        return count == 1 ? "1 gasto · \(total)" : "\(count) gastos · \(total)"
    }

    // MARK: Table

    private var table: some View {
        Table(rows, selection: $viewModel.selection, sortOrder: $sortOrder) {
            TableColumn("Descrição", value: \.description)

            TableColumn("Data", value: \.date) { expense in
                Text(Formatters.displayDate(fromISO: expense.date))
                    .monospacedDigit()
            }
            .width(min: 90, ideal: 110, max: 140)

            TableColumn("Categoria", value: \.category.displayName) { expense in
                Text(expense.category.displayName)
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 100, max: 140)

            TableColumn("Valor", value: \.amount) { expense in
                Text(Formatters.currency(fromCents: expense.amount))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 110, ideal: 130, max: 180)
        }
        .contextMenu(forSelectionType: Expense.ID.self) { ids in
            if ids.count == 1, let expense = expense(in: ids) {
                Button("Editar", systemImage: "pencil") {
                    onEdit(expense)
                }
            }
            if !ids.isEmpty {
                Button("Excluir", systemImage: "trash", role: .destructive) {
                    pendingDeletion = ids
                }
            }
        } primaryAction: { ids in
            // Double click (or Return) on a row.
            if ids.count == 1, let expense = expense(in: ids) {
                onEdit(expense)
            }
        }
        // The Delete key and the Edit > Delete menu command.
        .onDeleteCommand {
            pendingDeletion = viewModel.selection
        }
        .overlay {
            if rows.isEmpty {
                emptyState
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if viewModel.expenses.isEmpty {
            ContentUnavailableView(
                "Nenhum gasto registrado neste mês",
                systemImage: "tray",
                description: Text("Os gastos lançados em \(Formatters.displayMonth(viewModel.month)) aparecem aqui.")
            )
        } else {
            ContentUnavailableView(
                "Nenhum gasto nesta categoria",
                systemImage: "line.3.horizontal.decrease.circle",
                description: Text("Há gastos neste mês em outra categoria.")
            )
        }
    }

    private func expense(in ids: Set<Expense.ID>) -> Expense? {
        viewModel.expenses.first { ids.contains($0.id) }
    }

    // MARK: Deletion

    private var isConfirmingDeletion: Binding<Bool> {
        Binding(
            get: { !pendingDeletion.isEmpty },
            set: { isPresented in
                if !isPresented { pendingDeletion = [] }
            }
        )
    }

    private var deletionTitle: String {
        if pendingDeletion.count == 1,
           let expense = viewModel.expenses.first(where: { pendingDeletion.contains($0.id) }) {
            return "Excluir “\(expense.description)”?"
        }
        return "Excluir \(pendingDeletion.count) gastos?"
    }
}
