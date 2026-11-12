# Step 09 — Renda e resumo 50/30/20

## Objetivo

Mostrar o mês de relance: quanto entrou, quanto saiu e como isso se compara à regra 50/30/20 (50% da renda para gastos fixos, 30% para variáveis, 20% para investir).

- `Views/Dashboard/IncomeSummaryView.swift` (novo): quatro cards acima da tabela.
- `Views/Dashboard/DashboardView.swift` (alterado): empilha o resumo e a tabela.

Os cálculos já existiam no ViewModel desde o [Step 05](step-05-dashboard-viewmodel.md) (`total`, `totalFixed`, `totalVariable`, `fixedTarget`, `variableTarget`, `investmentTarget`, `saveIncome`). Este step é só apresentação.

## Decisões

### Meta e gasto real lado a lado, com barra de progresso

A web mostra as metas (50/30/20) em um bloco e os totais reais em outro, e a comparação fica por conta de quem lê. Como este é o cliente de análise, cada card junta as duas coisas: o total gasto, uma barra de quanto da meta foi consumido e uma frase com a diferença ("Restam R$ 1.649,50 de R$ 1.800,00" ou "R$ 380,21 acima da meta de R$ 3.000,00").

| Opção | O que oferece | O que custa |
|---|---|---|
| Só texto, como a web | Paridade exata | A conta de cabeça fica com o usuário |
| `ProgressView` + frase (escolhida) | A situação é lida de relance; estourar a meta fica vermelho | Um pouco mais de código de apresentação |
| Gráfico com Swift Charts | Mais expressivo | Fora do escopo desta fase; fica para a análise |

### A barra para em 100%

`ProgressView` não representa valores acima do total. Quando o gasto passa da meta, a barra fica cheia e **vermelha**, e o texto diz em quanto passou. O excesso é informado pela cor e pela frase, não pelo comprimento.

### Metas a partir da renda salva, não do que está sendo digitado

Na web, as metas mudam a cada tecla no campo de renda. Aqui, só mudam depois de "Salvar". Com as barras comparando meta e gasto, metas que oscilam enquanto se digita "6", "60", "600" fariam os cards piscar entre vermelho e normal. O valor digitado é um rascunho; o painel mostra o que está gravado.

### Campo vazio significa renda zero

A API devolve `amount: 0` para um mês sem renda. O campo mostra vazio (com o placeholder "0,00") em vez de "0,00" preenchido, e salvar o campo vazio grava zero. Com renda zero, os cards trocam a barra pela frase "Defina a renda para ver as metas", em vez de mostrar "R$ 380,00 acima da meta de R$ 0,00".

### "Salvar" só habilita quando há o que salvar

O botão fica desabilitado se o texto não é um valor válido ou se é igual à renda já gravada. Evita uma chamada inútil à API e mostra que não há alteração pendente.

### Card de investimentos mostra o saldo

Não existe categoria "investimento" entre os gastos, então não há um "gasto real" para comparar com os 20%. O card mostra a meta e o **saldo do mês** (renda menos total gasto): é o que de fato sobrou para investir. O saldo fica vermelho quando é menor que a meta.

## Como o código funciona

### Rascunho local sincronizado com o ViewModel

```swift
@State private var incomeText = ""

.onChange(of: [viewModel.month, String(viewModel.income)], initial: true) {
    incomeText = viewModel.income == 0 ? "" : Formatters.amountText(fromCents: viewModel.income)
}
```

`incomeText` é o que está no campo. `onChange` observa um valor e roda o bloco quando ele muda; aqui o valor é um array com o mês e a renda, então o campo é repreenchido quando **qualquer um dos dois** muda: ao trocar de mês, ao terminar de carregar e depois de salvar. `initial: true` roda o bloco também na primeira vez que a View aparece.

### Do texto para centavos

```swift
private var typedIncome: Int? {
    let trimmed = incomeText.trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? 0 : Formatters.parseAmountToCents(trimmed)
}
```

Três resultados possíveis: `0` (campo vazio), um valor em centavos, ou `nil` (texto inválido, que mostra a dica em vermelho).

### Componentes privados no mesmo arquivo

`BudgetCard`, `CardTitle` e `Card` são `private struct`: só existem para este arquivo. Extrair pedaços repetidos em Views pequenas é o jeito de reaproveitar layout em SwiftUI.

`Card` é **genérico** sobre seu conteúdo:

```swift
private struct Card<Content: View>: View {
    @ViewBuilder let content: Content
```

`@ViewBuilder` permite passar o conteúdo como um bloco de Views (`Card { Text(...); ProgressView(...) }`), do mesmo jeito que `VStack` e `HStack` fazem. O card aplica o que é comum: espaçamento, fundo neutro, cantos arredondados e a borda sutil (`.strokeBorder(.separator)`), a mesma linguagem visual da web.

### Cards da mesma altura

```swift
HStack(alignment: .top, spacing: 12) { ...cards... }
    .fixedSize(horizontal: false, vertical: true)
```

Cada card tem `maxHeight: .infinity` (ocupa a altura que lhe derem), e `fixedSize(vertical: true)` faz o `HStack` adotar a altura do card mais alto. O resultado: todos ficam com a altura do maior, sem número fixo.

### `BudgetCard`

Recebe só valores (`spent`, `target`, `hasIncome`), não o ViewModel. Assim o mesmo componente serve a "Fixo" e a "Variável", e não depende de onde os números vêm.

```swift
ProgressView(value: Double(min(spent, target)), total: Double(max(target, 1)))
    .tint(isOverTarget ? .red : .accentColor)
```

`min(spent, target)` limita a barra a 100%. `max(target, 1)` evita total zero. A conversão para `Double` aqui é só para desenhar a barra; nenhum valor em dinheiro é calculado com ela.

### Composição na tela

```swift
VStack(spacing: 0) {
    IncomeSummaryView(viewModel: viewModel)
    Divider()
    ExpenseTableView(viewModel: viewModel) { ... }
}
```

Os dois leem o mesmo ViewModel. Criar, editar ou excluir um gasto na tabela atualiza os cards no mesmo instante, sem nenhum código de sincronização: é o `@Observable` do Step 05 funcionando.

### O que foi conferido no app

- Mês com gastos e sem renda: totais por categoria e "Defina a renda para ver as metas".
- Renda "6.000,00" + Salvar: Fixo R$ 3.380,21 em vermelho ("R$ 380,21 acima da meta de R$ 3.000,00"), Variável com "Restam R$ 1.649,50 de R$ 1.800,00", Investimentos R$ 1.200,00 com saldo R$ 2.469,29.
- A API local guarda `600000`, e o valor volta ao reabrir o app.
- Outro mês, sem gastos nem renda: cards zerados e campo vazio.

## Conexão com a próxima etapa

Falta a última funcionalidade para a paridade com a web: juntar vários gastos em um. O [Step 10](step-10-consolidate.md) usa a seleção múltipla da tabela e o `consolidate` do ViewModel.
