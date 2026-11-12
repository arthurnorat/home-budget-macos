import SwiftUI

/// The month at a glance: the income (editable) and the 50/30/20 targets
/// compared with what was really spent.
struct IncomeSummaryView: View {
    let viewModel: DashboardViewModel

    /// What is typed in the income field; a draft until "Salvar" is pressed.
    @State private var incomeText = ""
    @State private var isSaving = false

    private var typedIncome: Int? {
        let trimmed = incomeText.trimmingCharacters(in: .whitespaces)
        // An empty field means "no income", which the API stores as zero.
        return trimmed.isEmpty ? 0 : Formatters.parseAmountToCents(trimmed)
    }

    private var canSave: Bool {
        guard let typedIncome else { return false }
        return typedIncome != viewModel.income && !isSaving
    }

    private var balance: Int { viewModel.income - viewModel.total }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            incomeCard

            BudgetCard(
                title: "Fixo",
                subtitle: "meta de 50%",
                spent: viewModel.totalFixed,
                target: viewModel.fixedTarget,
                hasIncome: viewModel.income > 0
            )

            BudgetCard(
                title: "Variável",
                subtitle: "meta de 30%",
                spent: viewModel.totalVariable,
                target: viewModel.variableTarget,
                hasIncome: viewModel.income > 0
            )

            investmentCard
        }
        // All cards take the height of the tallest one.
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        // Refill the field whenever the saved income or the month changes.
        .onChange(of: [viewModel.month, String(viewModel.income)], initial: true) {
            incomeText = viewModel.income == 0 ? "" : Formatters.amountText(fromCents: viewModel.income)
        }
    }

    // MARK: Cards

    private var incomeCard: some View {
        Card {
            CardTitle(title: "Renda do mês", subtitle: nil)

            HStack(spacing: 8) {
                TextField("Renda do mês", text: $incomeText, prompt: Text("0,00"))
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .onSubmit { saveIncome() }

                Button("Salvar") { saveIncome() }
                    .disabled(!canSave)
            }

            if typedIncome == nil {
                Text("Digite um valor como 5.000,00.")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text("Total gasto: \(Formatters.currency(fromCents: viewModel.total))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var investmentCard: some View {
        Card {
            CardTitle(title: "Investimentos", subtitle: "meta de 20%")

            Text(Formatters.currency(fromCents: viewModel.investmentTarget))
                .font(.title3.weight(.semibold))
                .monospacedDigit()

            if viewModel.income > 0 {
                Text("Saldo do mês: \(Formatters.currency(fromCents: balance))")
                    .font(.caption)
                    .foregroundStyle(balance < viewModel.investmentTarget ? .red : .secondary)
            } else {
                Text("Defina a renda para ver as metas.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func saveIncome() {
        guard canSave, let typedIncome else { return }
        isSaving = true
        Task {
            _ = await viewModel.saveIncome(typedIncome)
            isSaving = false
        }
    }
}

// MARK: - Building blocks

/// One spending category against its target.
private struct BudgetCard: View {
    let title: String
    let subtitle: String
    let spent: Int
    let target: Int
    let hasIncome: Bool

    private var isOverTarget: Bool { hasIncome && spent > target }

    private var detail: String {
        guard hasIncome else { return "Defina a renda para ver as metas." }
        let difference = Formatters.currency(fromCents: abs(target - spent))
        return isOverTarget
            ? "\(difference) acima da meta de \(Formatters.currency(fromCents: target))"
            : "Restam \(difference) de \(Formatters.currency(fromCents: target))"
    }

    var body: some View {
        Card {
            CardTitle(title: title, subtitle: subtitle)

            Text(Formatters.currency(fromCents: spent))
                .font(.title3.weight(.semibold))
                .monospacedDigit()

            if hasIncome {
                // The bar stops at 100%; going over is shown by the color and the text.
                ProgressView(value: Double(min(spent, target)), total: Double(max(target, 1)))
                    .tint(isOverTarget ? .red : .accentColor)
            }

            Text(detail)
                .font(.caption)
                .foregroundStyle(isOverTarget ? .red : .secondary)
        }
    }
}

private struct CardTitle: View {
    let title: String
    let subtitle: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .fixedSize()
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

/// Neutral box with a subtle border, the same visual language as the web.
private struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.separator)
        }
    }
}
