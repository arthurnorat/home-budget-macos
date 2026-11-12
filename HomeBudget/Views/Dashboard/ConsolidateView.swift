import SwiftUI

/// Sheet that confirms replacing the selected expenses with a single one.
/// Only the description can be changed; the rest comes from the selection.
struct ConsolidateView: View {
    let viewModel: DashboardViewModel
    let draft: ConsolidationDraft

    @Environment(\.dismiss) private var dismiss

    @State private var description: String
    @State private var isSaving = false

    init(viewModel: DashboardViewModel, draft: ConsolidationDraft) {
        self.viewModel = viewModel
        self.draft = draft
        _description = State(initialValue: draft.description)
    }

    private var trimmedDescription: String {
        description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canConfirm: Bool {
        trimmedDescription.count >= 2 && !isSaving
    }

    var body: some View {
        Form {
            Section {
                TextField("Descrição", text: $description)
                LabeledContent("Valor total", value: Formatters.currency(fromCents: draft.amount))
                LabeledContent("Data", value: Formatters.displayDate(fromISO: draft.date))
                LabeledContent("Categoria", value: draft.category.displayName)
            } header: {
                Text("Consolidar \(draft.count) gastos")
            } footer: {
                Text("Os \(draft.count) gastos selecionados serão substituídos por um só. Esta ação não pode ser desfeita.")
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
                Button("Consolidar") {
                    Task { await confirm() }
                }
                .disabled(!canConfirm)
            }
        }
        .disabled(isSaving)
    }

    private func confirm() async {
        isSaving = true
        defer { isSaving = false }
        // Close either way: on failure the view model reloads the month,
        // so this draft no longer describes what is on screen.
        _ = await viewModel.consolidate(description: trimmedDescription)
        dismiss()
    }
}
