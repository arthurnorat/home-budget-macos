# Etapa 1 — Models

## Objetivo desta etapa

Antes de desenhar qualquer tela ou fazer qualquer chamada de rede, o app precisa do "vocabulário" — os tipos de dados que representam as coisas com que ele trabalha: um gasto, uma categoria, uma renda mensal. Isso é a camada de **Models**.

Nesta etapa criamos cinco arquivos em `HomeBudget/Models/`:

- `Category.swift`
- `Expense.swift`
- `ExpenseRequest.swift`
- `MonthlyIncome.swift`
- `IncomeRequest.swift`

Nenhum deles ainda é usado por uma tela ou por código de rede — são só as "formas" dos dados. Assim como no projeto iOS, construímos a base primeiro, confirmamos que compila, e só então empilhamos a próxima camada em cima (Helpers, depois Services, depois ViewModel, depois Views).

---

## `Category.swift`, `Expense.swift` e `ExpenseRequest.swift` — reaproveitados do iOS

Esses três arquivos são **idênticos** aos do projeto iOS (`~/iOS_Projects/HomeBudget/HomeBudget/Models/`). Faz sentido: o contrato de API (`GET/POST/PUT/DELETE /expenses`) é o mesmo para os dois clientes — o mesmo `Expense` que o iOS recebe do servidor é exatamente o que o macOS vai receber.

```swift
// Category.swift
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

```swift
// Expense.swift — o gasto como ele existe no servidor
struct Expense: Identifiable, Codable, Equatable {
    let expenseId: String
    let description: String
    let amount: Int       // centavos, nunca Double — evita erro de ponto flutuante
    let date: String      // "yyyy-MM-dd", string crua vinda da API
    let category: Category
    let createdAt: String
}
```

```swift
// ExpenseRequest.swift — o gasto como o app envia ao criar OU editar
struct ExpenseRequest: Encodable {
    let description: String
    let amount: Int
    let date: String
    let category: Category
}
```

O raciocínio completo por trás de cada decisão (`enum` para categoria em vez de `String` solta, `amount` em centavos, `date`/`createdAt` como `String` em vez de `Date`, separação entre "o que envio" — `ExpenseRequest` — e "o que recebo" — `Expense`, por que não precisa de `CodingKeys`) já está documentado na Etapa 1 do iOS e continua valendo aqui sem alteração — não vou repetir.

Uma diferença de uso, não de tipo: no iOS, `ExpenseRequest` só é usado para **criar** (`POST`), porque editar está fora do escopo mobile. No macOS, o mesmo tipo será reaproveitado tanto para criar (`POST /expenses`) quanto para editar (`PUT /expenses/{id}`) — o contrato de API já usa o mesmo formato de body para os dois casos, então não é preciso um tipo `ExpenseUpdateRequest` separado.

---

## `MonthlyIncome.swift` e `IncomeRequest.swift` — novos, não existem no iOS

O iOS não tem esses models porque renda mensal está fora do escopo do app de lançamento rápido. O macOS, sendo a ferramenta de análise e planejamento, precisa deles desde já para o futuro resumo 50/30/20.

```swift
import Foundation

struct MonthlyIncome: Codable, Equatable {
    let month: String
    let amount: Int
}
```

```swift
import Foundation

struct IncomeRequest: Encodable {
    let amount: Int
}
```

### Por que `month: String` e não um id separado

O contrato de API (`GET/PUT /income?month=yyyy-MM`) usa o próprio mês (`"yyyy-MM"`) como **chave natural** — não existe um `incomeId` gerado pelo banco, como existe `expenseId` para gastos. Isso é uma decisão do backend: só pode existir uma renda por mês, então o mês já identifica o registro de forma única. `MonthlyIncome` reflete isso literalmente — sem propriedade `id` nem conformidade a `Identifiable`, porque (por enquanto) não vamos listar rendas de vários meses numa `List`/`ForEach` do SwiftUI; sempre trabalhamos com "a renda do mês selecionado", um valor só por vez.

### Por que `IncomeRequest` só tem `amount`

Olhando o contrato: `PUT /income?month=yyyy-MM` já recebe o mês **na URL** (query param), não no corpo da requisição — o body é só `{ "amount": 500000 }`. Por isso `IncomeRequest` não repete o campo `month`; ele não pertence ao corpo da requisição, e sim aos parâmetros da chamada HTTP, que serão montados na camada de Service (Etapa 3), não no model.

### Por que `Codable` em `MonthlyIncome` mas só `Encodable` em `IncomeRequest`

Mesmo raciocínio já aplicado a `Expense`/`ExpenseRequest`: `MonthlyIncome` é algo que o app **recebe** da API (`GET /income` e a resposta de `PUT /income`), então precisa decodificar — daí `Codable` (`Decodable` + `Encodable`). `IncomeRequest` é algo que o app só **envia** (corpo do `PUT`), nunca recebe de volta nesse formato — daí bastar `Encodable`, comunicando a intenção de "tipo só de saída" a quem ler o código depois.

---

## Conectando com o restante do plano

Esses cinco tipos são a base de tudo que vem depois:

- **Etapa 2 (Helpers)** vai converter `amount: Int` (centavos) para texto "R$ 15,50" e `date`/`createdAt` (`String`) para `Date`/texto formatado — tanto para `Expense` quanto para `MonthlyIncome`, sem alterar nenhum dos models.
- **Etapa 3 (Services)** vai ter dois services: `ExpenseService` (usa `Expense`/`ExpenseRequest`) e `IncomeService` (usa `MonthlyIncome`/`IncomeRequest`), cada um isolando as chamadas HTTP do seu recurso.
- **Etapa 4 (ViewModel)** vai manter em memória a lista `[Expense]` do mês selecionado e o `MonthlyIncome` do mesmo mês, calculando os totais e as metas 50/30/20 a partir desses dois.
- **Etapas 6–8 (Views)** vão exibir `Expense`s na tabela do dashboard, `Category.allCases` no seletor de categoria do formulário, e `MonthlyIncome`/`IncomeRequest` no painel de resumo/renda.

## Verificação desta etapa

Abrir o Xcode, confirmar que os cinco arquivos aparecem em `HomeBudget/Models/` no navegador de arquivos (grupos sincronizados — o Xcode inclui automaticamente qualquer `.swift` dentro da pasta) e rodar Build (⌘B). Como nenhum outro arquivo ainda referencia esses tipos, a verificação por enquanto é só confirmar que compila sem erros nem warnings antes de seguir para a Etapa 2 (Helpers).
