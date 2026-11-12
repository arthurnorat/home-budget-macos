import SwiftUI

/// Toolbar controls to move between months: previous and next sit beside the
/// month title; "Hoje" returns to the current month.
struct MonthNavigatorView: ToolbarContent {
    let viewModel: DashboardViewModel

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button("Mês anterior", systemImage: "chevron.left") {
                viewModel.goToPreviousMonth()
            }
            .keyboardShortcut(.leftArrow, modifiers: .command)
            .help("Mês anterior (⌘←)")

            Button("Próximo mês", systemImage: "chevron.right") {
                viewModel.goToNextMonth()
            }
            .keyboardShortcut(.rightArrow, modifiers: .command)
            .help("Próximo mês (⌘→)")
        }

        ToolbarItem(placement: .primaryAction) {
            Button("Hoje") {
                viewModel.goToCurrentMonth()
            }
            .keyboardShortcut("t", modifiers: .command)
            .disabled(viewModel.isCurrentMonth)
            .help("Voltar ao mês atual (⌘T)")
        }
    }
}
