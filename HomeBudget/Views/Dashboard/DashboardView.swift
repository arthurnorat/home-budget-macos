import SwiftUI

/// The month screen. It decides which of the four states to show
/// (loading, error, empty, content) and hosts the toolbar.
struct DashboardView: View {
    @Bindable var viewModel: DashboardViewModel

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(viewModel.monthTitle)
            .toolbar {
                MonthNavigatorView(viewModel: viewModel)
            }
            // Runs on appear and again every time the month changes,
            // cancelling the previous load if it is still running.
            .task(id: viewModel.month) {
                await viewModel.load()
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
        } else if viewModel.expenses.isEmpty {
            ContentUnavailableView(
                "Nenhum gasto registrado neste mês",
                systemImage: "tray",
                description: Text("Os gastos lançados em \(Formatters.displayMonth(viewModel.month)) aparecem aqui.")
            )
        } else {
            List(viewModel.expenses) { expense in
                LabeledContent(expense.description, value: Formatters.currency(fromCents: expense.amount))
            }
        }
    }
}
