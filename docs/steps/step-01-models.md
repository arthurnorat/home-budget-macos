# Step 01 — Models

## Objetivo

Antes de desenhar qualquer tela ou fazer qualquer chamada de rede, o app precisa do seu vocabulário: os tipos que representam um gasto, uma categoria e a renda de um mês. Essa é a camada de **Models**, em `HomeBudget/Models/`:

- `Category.swift`
- `Expense.swift`
- `ExpenseRequest.swift`
- `MonthlyIncome.swift`
- `IncomeRequest.swift`

Nenhum deles faz nada sozinho. Eles só descrevem a forma dos dados que a API envia e recebe, e todas as camadas seguintes (Helpers, Services, ViewModel, Views) são construídas em cima deles.

## Decisões

### Categoria como `enum`, não como `String`

| Opção | O que oferece | O que custa |
|---|---|---|
| `String` solta (`"FIXED"`) | Nenhum tipo novo | Um erro de digitação (`"FIXO"`) compila e só falha em produção |
| `enum Category: String` (escolhida) | O compilador só aceita `.fixed` e `.variable`; `switch` obriga a tratar todos os casos | Um arquivo a mais |

O `enum` com valor bruto `String` dá as duas coisas: segurança no código e o texto exato que a API espera (`"FIXED"`, `"VARIABLE"`) na hora de codificar.

### Dinheiro em centavos inteiros (`Int`), nunca `Double`

`0.1 + 0.2` em ponto flutuante dá `0.30000000000000004`. Somar centenas de gastos em `Double` acumula esse erro. Com `Int` em centavos (R$ 15,50 = `1550`), toda soma é exata. A conversão para "R$ 15,50" acontece só na hora de exibir (Step 02). A API já trabalha assim, então o model apenas respeita o contrato.

### Datas como `String`, não como `Date`

A API envia `date` como `"2026-07-27"` e `createdAt` como timestamp ISO. Guardar como `Date` exigiria configurar estratégias de decodificação e traria um risco real: uma data sem hora convertida para `Date` vira meia-noite em algum fuso, e pode "voltar um dia" ao ser exibida em outro. Como `String`, o valor trafega intacto e a conversão é feita de forma controlada pelos `Formatters`, só quando necessário.

### Tipos separados para o que se envia e o que se recebe

`Expense` é o gasto como existe no servidor (tem `expenseId` e `createdAt`, gerados pelo backend). `ExpenseRequest` é o que o app envia (só os quatro campos que o usuário preenche). Usar um tipo só obrigaria a ter `expenseId` e `createdAt` opcionais, e todo o resto do código teria de lidar com um "talvez exista". Com dois tipos, um `Expense` sempre tem id.

O mesmo `ExpenseRequest` serve para criar (`POST /expenses`) e editar (`PUT /expenses/{id}`), porque a API usa o mesmo corpo nos dois casos. Um `ExpenseUpdateRequest` separado seria uma cópia idêntica.

### `MonthlyIncome` sem `id`

A API identifica a renda pelo próprio mês (`GET/PUT /income?month=yyyy-MM`): só existe uma renda por mês, então o mês é a chave natural. O model reflete isso e não conforma a `Identifiable`, porque o app sempre trabalha com "a renda do mês selecionado", nunca com uma lista de rendas.

### `IncomeRequest` só com `amount`

No `PUT /income?month=yyyy-MM` o mês vai na URL e o corpo é apenas `{ "amount": 500000 }`. Colocar `month` no model enviaria um campo que a API não espera no corpo. O mês é parâmetro da chamada, montado no Service (Step 03).

### `Codable` ou só `Encodable`

`Expense` e `MonthlyIncome` chegam da API, então precisam decodificar (`Codable` = `Decodable` + `Encodable`). `ExpenseRequest` e `IncomeRequest` só saem do app, então basta `Encodable`. Isso também documenta a intenção: quem lê o código vê que são tipos só de saída.

## ADR — Arquitetura do cliente macOS

**Contexto.** O sistema HomeBudget tem uma API e quatro clientes (web, iOS, Android, macOS). O iOS, também em Swift, já tinha Models, Formatters e Service prontos. O macOS tem um papel diferente: é o cliente de análise e planejamento, enquanto os apps móveis só lançam gastos rápidos. Havia três decisões estruturais a tomar antes da primeira linha de código.

**Decisão.**

1. **Não compartilhar código com o iOS.** Nenhum Swift Package comum; o macOS mantém sua própria cópia de Models, Helpers e Services.
2. **MVVM simples**: Views (SwiftUI) → ViewModel (`@Observable`) → Services (`URLSession`). Views não fazem chamadas HTTP nem têm regra de negócio.
3. **`NavigationSplitView` desde o início**: janela com sidebar, mesmo havendo uma única seção hoje.

**Alternativas consideradas.**

- *Swift Package compartilhado com o iOS*: evitaria duplicar ~100 linhas, mas amarraria dois apps com escopos opostos. Cada mudança no macOS (edição, renda, análise) exigiria versionar um pacote e revalidar o iOS. O Android já vive sem compartilhar código com o iOS, e o custo da duplicação aqui é pequeno.
- *Views chamando a API diretamente*: menos arquivos, mas a lógica (totais, filtro, consolidação) ficaria espalhada pelas telas e impossível de reaproveitar entre elas.
- *Janela única, como a web*: mais simples hoje, mas a primeira seção de análise (gráficos, relatórios) obrigaria a redesenhar a navegação inteira.

**Consequências.** Uma mudança no contrato da API precisa ser replicada à mão em cada cliente. Em troca, o macOS evolui sem risco para o iOS. Reverter a decisão 1 significaria extrair um pacote e migrar dois projetos; reverter a 2 ou a 3 significaria reescrever todas as Views.

## Como o código funciona

### `Category.swift`

```swift
enum Category: String, Codable, CaseIterable, Identifiable {
    case fixed = "FIXED"
    case variable = "VARIABLE"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fixed: return "Fixo"
        case .variable: return "Variável"
        }
    }
}
```

- `: String` define o **valor bruto** (raw value): `.fixed` vale `"FIXED"`. É esse texto que vai para o JSON.
- `Codable` permite converter de e para JSON. Como o enum tem valor bruto `String`, o Swift gera essa conversão sozinho.
- `CaseIterable` cria `Category.allCases` (`[.fixed, .variable]`), usado para montar o seletor de categoria sem listar os casos à mão.
- `Identifiable` exige um `id` estável. O SwiftUI usa isso em `ForEach` e `Picker` para saber qual item é qual.
- `displayName` é o texto mostrado ao usuário. Fica em português por ser interface, não identificador.

### `Expense.swift`

```swift
struct Expense: Identifiable, Codable, Equatable {
    let expenseId: String
    let description: String
    let amount: Int
    let date: String
    let category: Category
    let createdAt: String

    var id: String { expenseId }
}
```

Os nomes das propriedades são idênticos aos campos do JSON da API (`expenseId`, `createdAt`, em camelCase), então o `JSONDecoder` faz o mapeamento sozinho, sem `CodingKeys`. `id` é uma propriedade computada que aponta para `expenseId`, satisfazendo `Identifiable`. `Equatable` permite comparar dois gastos com `==`, o que o SwiftUI usa para decidir se precisa redesenhar uma linha.

Exemplo: o JSON

```json
{ "expenseId": "a1", "description": "Mercado", "amount": 15000,
  "date": "2026-07-27", "category": "VARIABLE", "createdAt": "2026-07-27T10:30:00Z" }
```

vira um `Expense` com `amount == 15000` (R$ 150,00) e `category == .variable`.

### `ExpenseRequest.swift`, `MonthlyIncome.swift`, `IncomeRequest.swift`

```swift
struct ExpenseRequest: Encodable {
    let description: String
    let amount: Int
    let date: String
    let category: Category
}

struct MonthlyIncome: Codable, Equatable {
    let month: String   // "yyyy-MM"
    let amount: Int     // centavos
}

struct IncomeRequest: Encodable {
    let amount: Int
}
```

São `struct`s (tipos de valor): copiar um deles cria uma cópia independente, sem estado compartilhado. Todas as propriedades são `let`, então um valor recebido da API nunca é alterado; para "mudar" um gasto, o app pede à API e recebe um novo `Expense`.

## Conexão com a próxima etapa

Os models guardam os dados crus (`1550`, `"2026-07-27"`, `"2026-07"`). O [Step 02](step-02-helpers.md) cria os `Formatters`, que convertem esses valores para o que o usuário lê ("R$ 15,50", "27/07/2026", "julho de 2026") e de volta.
