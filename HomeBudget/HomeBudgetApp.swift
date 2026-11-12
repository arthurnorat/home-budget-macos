import SwiftUI

@main
struct HomeBudgetApp: App {
    /// The app owns the view model, so it lives as long as the app does.
    @State private var viewModel = DashboardViewModel()

    var body: some Scene {
        // `Window` (not `WindowGroup`): the budget has a single window.
        Window("HomeBudget", id: "main") {
            RootView(viewModel: viewModel)
        }
        .defaultSize(width: 980, height: 680)
    }
}
