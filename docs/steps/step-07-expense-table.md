# Step 07 — Tabela de gastos

## Objetivo

Substituir a lista provisória do [Step 06](step-06-window-shell.md) pela peça central do app: uma tabela dos gastos do mês, com filtro por categoria, ordenação por coluna, seleção e exclusão.

- `Views/Dashboard/ExpenseTableView.swift` (novo)
- `Views/Dashboard/DashboardView.swift` (alterado): usa a tabela e ganha o alerta de erro de ação.

## Decisões

### `Table` nativa em vez de `List` com linhas customizadas

| Opção | O que oferece | O que custa |
|---|---|---|
| `List` + `ExpenseRowView` (plano original, como no iOS) | Controle total do desenho de cada linha | Cabeçalhos, ordenação, larguras de coluna e seleção múltipla teriam de ser feitos à mão |
| `Table` (escolhida) | Colunas redimensionáveis, cabeçalho clicável para ordenar, seleção com ⌘ e ⇧, navegação por teclado: tudo do sistema | Menos liberdade visual; só existe no macOS e iPadOS |

Para uma tela de análise densa, a `Table` entrega o comportamento que um usuário de Mac já espera. Por isso `ExpenseRowView.swift`, previsto no plano inicial, não existe: cada coluna define sua própria célula.

### Seleção nativa em vez de checkboxes

A web usa uma coluna de checkboxes para marcar os gastos a consolidar. No Mac, selecionar linhas (clique, ⌘+clique, ⇧+clique, ⇧+setas) já é o gesto padrão. A seleção da tabela é ligada direto a `viewModel.selection`, e a mesma seleção serve para excluir, editar (Step 08) e consolidar (Step 10).

### O filtro mora no ViewModel; a ordenação, na View

O **filtro** muda *quais* gastos contam e é lido por outras partes (o resumo ao lado dele mostra a quantidade e o total filtrados), então é estado do ViewModel. A **ordenação** é só a forma de apresentar as mesmas linhas, não interessa a mais ninguém e é estado local da View (`@State sortOrder`).

### Confirmar antes de excluir

A web exclui no clique. Aqui a exclusão pede confirmação, porque a API não tem desfazer e, com seleção múltipla, um ⌫ pode apagar vários gastos de uma vez. O título do alerta diz exatamente o que será apagado: o nome do gasto, ou a quantidade.

### Três caminhos para a mesma ação

Excluir funciona pelo botão "Excluir" da barra, pela tecla ⌫ (e pelo menu Editar > Apagar) e pelo menu de contexto. Os três só preenchem `pendingDeletion`; a exclusão acontece em um único lugar, depois da confirmação.

### Dois estados vazios diferentes

"Nenhum gasto registrado neste mês" e "Nenhum gasto nesta categoria" são situações distintas: na segunda, há gastos, só não na categoria filtrada. Mostrar a primeira mensagem com o filtro "Fixo" ativo faria o usuário achar que o mês está vazio.

## Como o código funciona

### As linhas

```swift
private var rows: [Expense] {
    viewModel.filteredExpenses.sorted(using: sortOrder)
}
```

O ViewModel filtra, a View ordena. `sortOrder` é uma lista de `KeyPathComparator`, que descreve "ordene por esta propriedade, nesta direção". O valor inicial é data decrescente (mais recentes primeiro).

Um **key path** (`\Expense.date`) é uma referência a uma propriedade, sem lê-la: permite dizer "a propriedade `date` de um `Expense`" como um valor.

### A tabela

```swift
Table(rows, selection: $viewModel.selection, sortOrder: $sortOrder) {
    TableColumn("Descrição", value: \.description)

    TableColumn("Data", value: \.date) { expense in
        Text(Formatters.displayDate(fromISO: expense.date))
    }

    TableColumn("Valor", value: \.amount) { expense in
        Text(Formatters.currency(fromCents: expense.amount))
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
```

- `value:` diz por qual propriedade a coluna ordena. Clicar no cabeçalho altera `sortOrder`, o que recalcula `rows`.
- O bloco após a coluna desenha a célula. A coluna **ordena pelo dado cru e exibe o dado formatado**: a data ordena como `"2026-11-05"` (ordem cronológica correta) e aparece como "05/11/2026"; o valor ordena como inteiro e aparece como "R$ 2.000,00". Ordenar pelo texto formatado colocaria "R$ 9,50" depois de "R$ 150,50".
- `.monospacedDigit()` dá a mesma largura a todos os algarismos, alinhando as casas decimais.

### A barra de ações

Um `Picker` com estilo `.segmented` (Todos / Variável / Fixo) ligado a `$viewModel.filter`, o resumo ("4 gastos · R$ 2.296,15") e o botão "Excluir", desabilitado sem seleção.

### A confirmação

```swift
@State private var pendingDeletion: Set<Expense.ID> = []
```

O alerta aparece enquanto `pendingDeletion` não está vazio. Como `.alert` espera um `Binding<Bool>`, a View constrói um à mão:

```swift
Binding(
    get: { !pendingDeletion.isEmpty },
    set: { isPresented in
        if !isPresented { pendingDeletion = [] }
    }
)
```

`get` diz se o alerta deve estar visível; `set` é chamado pelo SwiftUI ao fechá-lo. Ao confirmar, a View chama `viewModel.delete(ids)` dentro de um `Task`.

### Erros de ação

`DashboardView` ganhou um alerta ligado a `viewModel.actionError`, com a mesma técnica de binding. Qualquer ação que falhe, em qualquer parte da tela, aparece ali.

### O que foi conferido no app

- Cinco gastos de teste listados com data, categoria e valor formatados.
- Filtro "Fixo" mostra só os dois fixos, com contagem e total recalculados.
- Clicar em "Valor" reordena por valor.
- Selecionar uma linha habilita "Excluir"; "Cancelar" não apaga nada.
- Confirmar a exclusão remove a linha, e a API local confirma que o gasto não existe mais.

## Conexão com a próxima etapa

Dá para ver e excluir gastos, mas não para lançar nem corrigir. O [Step 08](step-08-expense-form.md) cria o formulário de novo gasto e de edição.
