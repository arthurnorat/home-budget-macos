import SwiftUI

/// The sections listed in the sidebar. Only one exists today; analysis
/// sections (charts, reports) will be added here.
enum AppSection: String, CaseIterable, Identifiable {
    case budget

    var id: String { rawValue }

    var title: String {
        switch self {
        case .budget: return "Orçamento"
        }
    }

    var systemImage: String {
        switch self {
        case .budget: return "chart.pie"
        }
    }
}

/// The window: a sidebar with the sections and the selected section beside it.
struct RootView: View {
    let viewModel: DashboardViewModel
    @State private var section: AppSection? = .budget

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $section) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 190, max: 260)
        } detail: {
            switch section {
            case .budget, nil:
                DashboardView(viewModel: viewModel)
            }
        }
        // Below this size the four summary cards and the table columns no longer fit.
        .frame(minWidth: 860, minHeight: 520)
    }
}
