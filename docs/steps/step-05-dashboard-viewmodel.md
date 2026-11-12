# Step 05 — DashboardViewModel

## Objetivo

Os services sabem falar com a API, mas ninguém ainda decide **quando** chamar, **o que guardar** nem **o que fazer quando falha**. Esse é o papel do ViewModel, a camada do meio do MVVM:

- `HomeBudget/ViewModels/DashboardViewModel.swift`

Ele guarda o estado da tela (mês, gastos, renda, filtro, seleção, carregando, erro), calcula tudo o que deriva desse estado (totais, metas 50/30/20, prévia da consolidação) e expõe as ações do usuário (navegar, salvar, excluir, consolidar). As Views dos próximos steps só vão ler esse estado e chamar essas ações.

Toda a lógica do app fica aqui, de uma vez. As telas chegam depois, uma por step, cada uma usando uma parte do que já existe.

## Decisões

### Um ViewModel para o dashboard inteiro

| Opção | O que oferece | O que custa |
|---|---|---|
| Um ViewModel por componente (tabela, resumo, formulário) | Arquivos menores | Os três precisam dos mesmos gastos; seria preciso sincronizar cópias ou criar um quarto objeto compartilhado |
| Um `DashboardViewModel` (escolhida) | Uma só fonte de verdade: criar um gasto atualiza tabela e totais ao mesmo tempo | Um arquivo maior (~250 linhas) |

Tabela, totais e metas são três visões dos **mesmos dados**. Separá-los criaria o problema de mantê-los em sincronia.

### `@Observable` em vez de `ObservableObject`

`ObservableObject` (o modelo antigo) exige marcar cada propriedade com `@Published` e redesenha toda View que observa o objeto quando *qualquer* propriedade muda. `@Observable` (macOS 14+) dispensa a marcação e rastreia quais propriedades cada View realmente leu: mudar `filter` não redesenha o painel de renda. Menos código e menos trabalho de tela.

### Valores derivados são calculados, não guardados

`total`, `totalFixed`, `filteredExpenses`, `fixedTarget` são **propriedades computadas**: recalculadas a partir de `expenses` e `income` sempre que lidas. A alternativa (guardar o total em uma variável e atualizá-la a cada mudança) abre espaço para o total ficar desatualizado se alguma ação esquecer de atualizá-lo. Com algumas dezenas de gastos por mês, recalcular custa nada.

### Atualizar a lista localmente depois de cada ação

| Opção | O que oferece | O que custa |
|---|---|---|
| Recarregar o mês do servidor após cada ação (como a web faz) | A tela sempre reflete o servidor | Uma chamada extra e a tabela pisca "carregando" a cada gasto salvo |
| Usar a resposta da API para atualizar a lista em memória (escolhida) | Resposta imediata, sem recarregar | A lista pode divergir se o outro usuário alterar algo ao mesmo tempo |

A API devolve o gasto criado ou atualizado, então a lista local é atualizada com o dado **do servidor**, não com um palpite. A divergência com o outro usuário é resolvida pelo botão de atualizar (Step 11) e por qualquer troca de mês. Em caso de **falha**, o ViewModel recarrega do servidor, porque aí já não sabe o que foi aplicado.

### Dois lugares para erro: `loadError` e `actionError`

Falhar ao **carregar** o mês deixa a tela sem conteúdo: o erro ocupa o lugar da tabela, com "Tentar novamente". Falhar em uma **ação** (salvar, excluir) não invalida o que já está na tela: o erro aparece como alerta e os dados continuam visíveis. Um único campo de erro obrigaria a tela a adivinhar qual dos dois casos é.

### As ações devolvem `Bool`, não lançam erro

`save`, `saveIncome` e `consolidate` devolvem `true`/`false`. O erro em si já foi tratado dentro do ViewModel (virou `actionError`). O `Bool` existe só para o formulário saber se pode fechar. Assim nenhuma View precisa de `do`/`catch`, e a regra "a View não trata erro de rede" se mantém.

### Consolidar: criar primeiro, apagar depois

A API não tem endpoint de consolidação, então são várias chamadas, e qualquer uma pode falhar no meio.

- **Apagar e depois criar**: se a criação falhar, os gastos originais já sumiram e o dinheiro desaparece do mês.
- **Criar e depois apagar** (escolhida, igual à web): se uma exclusão falhar, sobra um gasto duplicado, que é visível e fácil de corrigir.

Entre perder dados e duplicar dados, duplicar é o erro recuperável.

### Resposta de um mês que já não é o atual é descartada

Clicando rápido em "próximo", a resposta de outubro pode chegar depois de o usuário já estar em novembro. `load()` guarda o mês pedido no início e, quando a resposta chega, só a aplica se `requestedMonth == month`.

### Porcentagens com inteiros

`share(of:percent:)` calcula `(amount * percent + 50) / 100`. O `+ 50` arredonda para o centavo mais próximo na divisão inteira. Os centavos nunca passam por `Double`.

## Como o código funciona

### Estado

```swift
@Observable
final class DashboardViewModel {
    private(set) var month: String
    private(set) var expenses: [Expense] = []
    private(set) var income: Int = 0

    var filter: CategoryFilter = .all
    var selection: Set<Expense.ID> = []

    private(set) var isLoading = false
    private(set) var loadError: String?
    var actionError: String?
```

`private(set)` significa "qualquer um lê, só o ViewModel escreve". A tela não pode fazer `viewModel.expenses = []`; precisa chamar uma ação. `filter`, `selection` e `actionError` são `var` comuns porque a tela escreve neles diretamente (o seletor de filtro, a seleção da tabela e o botão OK do alerta).

É uma `class` e não uma `struct` porque é um objeto com identidade: várias Views observam **o mesmo** ViewModel e precisam ver as mesmas mudanças.

### `CategoryFilter` e `ConsolidationDraft`

Dois tipos pequenos no mesmo arquivo. `CategoryFilter` (`.all`, `.variable`, `.fixed`) tem `matches(_:)`, que diz se um gasto passa no filtro. `ConsolidationDraft` é a prévia do que a consolidação criaria: descrição e categoria do primeiro selecionado, soma dos valores, data mais recente. Como as datas são strings ISO (`"2031-12-20"`), a maior string **é** a data mais recente, e `max()` resolve sem converter para `Date`.

### Carregar o mês em paralelo

```swift
async let expensesResult = fetchExpenses(month: requestedMonth)
async let incomeResult = fetchIncome(month: requestedMonth)
let newExpenses = try await expensesResult.get()
let newIncome = try await incomeResult.get()
```

`async let` inicia a chamada **sem esperar** por ela. As duas requisições partem juntas, e cada `await` só aguarda o resultado. O carregamento leva o tempo da mais lenta, não a soma das duas.

Há um detalhe de linguagem aqui: `async let` perde o tipo do erro (vira `any Error`), o que quebraria o `catch` tipado. Por isso os dois auxiliares privados devolvem `Result<[Expense], AppError>`, um valor que carrega sucesso ou falha, e `get()` relança a falha já como `AppError`.

No `catch`, uma requisição **cancelada** não é tratada como erro: significa só que um carregamento mais novo a substituiu.

### Salvar um gasto

```swift
func save(_ request: ExpenseRequest, editing: Expense? = nil) async -> Bool
```

Um método para criar e editar: com `editing`, chama `update`; sem, chama `create`. Depois remove a versão antiga da lista (se havia) e insere a nova, **desde que a data pertença ao mês exibido** (`saved.date.hasPrefix(month)`). Editar um gasto de dezembro e mudar a data para janeiro faz ele sair da lista de dezembro, que é o esperado.

### Excluir

`delete(_ ids:)` recebe um conjunto para servir tanto à exclusão de uma linha quanto à de várias selecionadas. Cada gasto é removido da lista assim que a API confirma. Se algum falhar, o alerta aparece e o mês é recarregado, mostrando o que o servidor realmente tem.

### Navegar

`goToPreviousMonth()`, `goToNextMonth()` e `goToCurrentMonth()` chamam `show(_:)`, que troca `month` e **limpa** gastos, renda e seleção. Sem essa limpeza, por um instante a tela mostraria os gastos de outubro sob o título "Novembro". Esses métodos não carregam nada: a View observa `month` e chama `load()` quando ele muda (Step 06).

### O que foi conferido

A lógica foi exercitada contra a API local com 26 verificações: mês vazio, criar, editar, totais, filtro, metas, persistência (um segundo ViewModel enxerga os mesmos dados), consolidação e sua persistência, virada de ano nos dois sentidos, erro 404 ao excluir algo já excluído, resposta de mês antigo descartada e servidor fora do ar.

## Conexão com a próxima etapa

Toda a lógica existe, mas nada aparece na tela. O [Step 06](step-06-window-shell.md) cria a janela com sidebar, o navegador de mês e a primeira carga real de dados dentro do app.
