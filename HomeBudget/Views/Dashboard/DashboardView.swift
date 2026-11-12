import SwiftUI

/// The month screen. It decides which state to show (error, loading or
/// content) and hosts the toolbar and the alert for failed actions.
struct DashboardView: View {
    @Bindable var viewModel: DashboardViewModel
    /// The form being presented, if any: a new expense or an existing one.
    @State private var formTarget: ExpenseFormTarget?
    /// The consolidation waiting for confirmation, if any.
    @State private var consolidationDraft: ConsolidationDraft?

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(viewModel.monthTitle)
            .toolbar {
                MonthNavigatorView(viewModel: viewModel)

                ToolbarItem(placement: .primaryAction) {
                    Button("Atualizar", systemImage: "arrow.clockwise") {
                        Task { await viewModel.load() }
                    }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(viewModel.isLoading)
                    .help("Buscar os dados do mês novamente (⌘R)")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Novo gasto", systemImage: "plus") {
                        formTarget = .new
                    }
                    .keyboardShortcut("n", modifiers: .command)
                    .help("Novo gasto (⌘N)")
                }
            }
            .sheet(item: $formTarget) { target in
                ExpenseFormView(viewModel: viewModel, editing: target.expense)
            }
            .sheet(item: $consolidationDraft) { draft in
                ConsolidateView(viewModel: viewModel, draft: draft)
            }
            // Runs on appear and again every time the month changes,
            // cancelling the previous load if it is still running.
            .task(id: viewModel.month) {
                await viewModel.load()
            }
            .alert("Não foi possível concluir", isPresented: isShowingActionError) {
                Button("OK") {}
            } message: {
                Text(viewModel.actionError ?? "")
            }
    }

    @ViewBuilder
    private var content: some View {
        if let message = viewModel.loadError {
            ContentUnavailableView {
                Label("Não foi possível carregar o mês", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Tentar novamente") {
                    Task { await viewModel.load() }
                }
            }
        } else if viewModel.isLoading && viewModel.expenses.isEmpty {
            ProgressView("Carregando…")
        } else {
            VStack(spacing: 0) {
                IncomeSummaryView(viewModel: viewModel)
                Divider()
                ExpenseTableView(
                    viewModel: viewModel,
                    onEdit: { expense in formTarget = .edit(expense) },
                    onConsolidate: { consolidationDraft = viewModel.consolidationDraft }
                )
            }
        }
    }

    /// The alert is shown while `actionError` has a message; dismissing it clears the message.
    private var isShowingActionError: Binding<Bool> {
        Binding(
            get: { viewModel.actionError != nil },
            set: { isPresented in
                if !isPresented { viewModel.actionError = nil }
            }
        )
    }
}
