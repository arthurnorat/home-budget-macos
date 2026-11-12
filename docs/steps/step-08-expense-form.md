# Step 08 — Formulário de gasto

## Objetivo

Permitir lançar um gasto novo e corrigir um existente, com um único formulário:

- `Views/ExpenseForm/ExpenseFormView.swift` (novo): o formulário, apresentado como sheet.
- `Views/Dashboard/DashboardView.swift` (alterado): botão "+" na toolbar e apresentação da sheet.
- `Views/Dashboard/ExpenseTableView.swift` (alterado): botão "Editar", duplo clique e item no menu de contexto.
- `Helpers/Formatters.swift` (alterado): `date(fromISO:)`, `amountText(fromCents:)` e `parseAmountToCents` aceitando separador de milhar.
- `ViewModels/DashboardViewModel.swift` (alterado): `defaultExpenseDate`.

## Decisões

### Sheet em vez de formulário fixo na página

| Opção | O que oferece | O que custa |
|---|---|---|
| Formulário sempre visível no topo (como a web) | Lançar sem abrir nada | Ocupa espaço permanente em uma tela cujo foco é analisar |
| Sheet aberta sob demanda (escolhida) | A tabela e o resumo ficam com a tela toda; ⌘N abre o formulário na hora | Um clique (ou atalho) a mais por lançamento |

O lançamento rápido do dia a dia é o papel do iOS e do Android. No Mac, o formulário é ocasional.

### Um formulário para criar e editar

A web usa o mesmo componente nos dois casos, e a API usa o mesmo corpo (`ExpenseRequest`). A diferença se resume a um parâmetro: `editing: Expense?`. Com `nil`, os campos começam vazios e o botão diz "Adicionar"; com um gasto, começam preenchidos e o botão diz "Salvar". Dois formulários seriam duas cópias a manter iguais.

### `sheet(item:)` com um enum

```swift
enum ExpenseFormTarget: Identifiable {
    case new
    case edit(Expense)
}
```

A alternativa seria um `Bool` (`isShowingForm`) mais um `Expense?` separado (`expenseBeingEdited`), dois estados que podem se contradizer (formulário aberto para editar, sem gasto definido). Um enum opcional tem exatamente três valores possíveis: fechado (`nil`), novo ou editando um gasto específico.

### Os campos do formulário são estado da View

Descrição, valor, data e categoria ficam em `@State` dentro do formulário, não no ViewModel. São um rascunho: só interessam enquanto a sheet está aberta e somem ao cancelar. O ViewModel só fica sabendo do gasto quando ele é salvo.

### Valor como texto, validado ao digitar

O campo de valor é um `TextField` de texto livre, convertido por `Formatters.parseAmountToCents`. A alternativa, um campo com formatador numérico do sistema, só valida ao sair do campo e se comporta de forma confusa com vírgula e ponto. Com texto, o botão de salvar reage a cada tecla, e a dica em vermelho aparece assim que o conteúdo deixa de ser um valor válido.

`parseAmountToCents` foi ajustado: se o texto tem vírgula, os pontos são tratados como separador de milhar. "1.234,56" agora vira `123456`; antes era rejeitado.

### Validação igual à da web, reforçada pela API

Descrição com pelo menos 2 caracteres (sem contar espaços nas pontas) e valor maior que zero. Enquanto isso não vale, o botão fica desabilitado. A API valida de novo (responde 422): a validação na tela é para dar retorno imediato, não para substituir a do servidor.

### Data padrão depende do mês exibido

Novo gasto no mês atual começa com a data de hoje. Em outro mês, começa no dia 1 **daquele mês**. Se começasse sempre com hoje, lançar um gasto olhando para outubro o gravaria em novembro, e ele não apareceria na lista que o usuário está vendo.

### O formulário só fecha se salvar

`viewModel.save` devolve `Bool`. Com `true`, a sheet fecha. Com `false`, o alerta de erro aparece e a sheet **continua aberta com o que foi digitado**, para tentar de novo sem redigitar.

## Como o código funciona

### Estado inicial a partir do gasto editado

```swift
init(viewModel: DashboardViewModel, editing: Expense?) {
    _description = State(initialValue: editing?.description ?? "")
    _amountText = State(initialValue: editing.map { Formatters.amountText(fromCents: $0.amount) } ?? "")
    _date = State(initialValue: editing.flatMap { Formatters.date(fromISO: $0.date) } ?? viewModel.defaultExpenseDate)
    _category = State(initialValue: editing?.category ?? .variable)
}
```

Uma propriedade `@State var description` tem, por baixo, um armazenamento chamado `_description`. Para dar um valor inicial que depende de um parâmetro do `init`, atribui-se a esse armazenamento com `State(initialValue:)`.

- `??` (*nil-coalescing*) usa o valor da direita quando o da esquerda é `nil`.
- `map` em um opcional transforma o valor se ele existir: `editing.map { ... }` formata o valor do gasto, ou continua `nil`.
- `flatMap` faz o mesmo quando a transformação também devolve opcional (`date(fromISO:)` pode falhar), evitando um opcional dentro de outro.

`Formatters.amountText(fromCents: 4575)` devolve `"45,75"`: o texto puro, sem "R$", para o campo de edição.

### Validação

```swift
private var canSave: Bool {
    trimmedDescription.count >= 2 && amountInCents != nil && !isSaving
}
```

Propriedades computadas: recalculadas a cada tecla, porque dependem de `@State`. `isSaving` impede o duplo envio enquanto a requisição está em andamento.

### Layout

`Form` com `.formStyle(.grouped)` desenha os campos no estilo dos Ajustes do sistema, com rótulo à esquerda e controle à direita. Os botões ficam em `.toolbar` com `placement: .cancellationAction` e `.confirmationAction`: em uma sheet, o sistema os posiciona no rodapé e liga **Esc** ao cancelar e **Return** ao confirmar.

`@Environment(\.dismiss)` dá à View uma função para se fechar, sem precisar saber quem a apresentou.

### Abrindo o formulário

Em `DashboardView`:

```swift
@State private var formTarget: ExpenseFormTarget?

.sheet(item: $formTarget) { target in
    ExpenseFormView(viewModel: viewModel, editing: target.expense)
}
```

A sheet aparece quando `formTarget` deixa de ser `nil` e o zera ao fechar. Quatro caminhos o preenchem:

| Gesto | Resultado |
|---|---|
| Botão "+" ou ⌘N | `.new` |
| Botão "Editar" (com exatamente um gasto selecionado) | `.edit(gasto)` |
| Duplo clique ou Return em uma linha | `.edit(gasto)` |
| Menu de contexto > Editar | `.edit(gasto)` |

A tabela não conhece o formulário: recebe um *closure* `onEdit: (Expense) -> Void` e o chama. Quem decide o que "editar" significa é a `DashboardView`.

### O que foi conferido no app

- "+" abre o formulário vazio, com a data de hoje e categoria Variável.
- Valor "abc" mostra a dica em vermelho e mantém "Adicionar" desabilitado.
- "Cancelar" fecha sem criar nada, e o formulário reabre limpo.
- "Seguro do carro", "1.234,56", Fixo: aparece na tabela como R$ 1.234,56 e a API local guarda `123456`.
- "Editar" abre com os dados do gasto; alterar descrição e categoria atualiza a linha, e a API local confirma.

## Conexão com a próxima etapa

O ciclo de gastos está completo. Falta o outro lado do orçamento: quanto entra. O [Step 09](step-09-income-summary.md) cria o painel de renda mensal e o resumo 50/30/20.
