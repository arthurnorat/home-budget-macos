# Step 03 — Services

## Objetivo

Até aqui o app sabe representar um gasto e uma renda ([Step 01](step-01-models.md)) e formatá-los ([Step 02](step-02-helpers.md)), mas nada conversa com o backend. Este step cria a camada que troca dados com a API:

- `HomeBudget/Services/ExpenseService.swift`
- `HomeBudget/Services/IncomeService.swift`

> **Atualização.** O [Step 04](step-04-app-error.md) reverteu duas decisões deste step: os dois tipos de erro (`ExpenseServiceError`, `IncomeServiceError`) foram unificados em `AppError`, e a montagem das requisições saiu dos services para um `APIClient` compartilhado. As operações e suas assinaturas continuam as descritas aqui.

## Decisões

### `URLSession`, sem biblioteca de rede

| Opção | O que oferece | O que custa |
|---|---|---|
| Alamofire ou similar | API mais curta, retry e interceptadores prontos | Uma dependência externa para seis chamadas simples |
| `URLSession` (escolhida) | Já vem no sistema, suporta `async/await`, nada a instalar ou atualizar | Algumas linhas a mais para montar requisição e validar resposta |

A API tem seis endpoints, sem autenticação nem upload. O que uma biblioteca economizaria não paga o custo de mantê-la.

### Um service por recurso

A API tem dois recursos independentes, `/expenses` e `/income`. Um `APIService` único com oito métodos misturaria os dois; um service por recurso mantém cada arquivo pequeno e com um só motivo para mudar.

### `struct`, não `class`

Um service não tem estado mutável: guarda só a configuração (`baseURL`, `session`) recebida no `init`. `struct` deixa isso explícito e evita referência compartilhada.

### Dependências pelo `init`, com valores padrão

```swift
init(baseURL: URL = ..., session: URLSession = .shared)
```

No uso normal basta `ExpenseService()`. Mas quem quiser apontar para outro servidor ou usar outra sessão pode passar os argumentos, sem alterar o service.

### URL por configuração de build (`#if DEBUG`)

Em Debug o app fala com `http://localhost:8080`; em Release, com o Cloud Run. Assim, rodar pelo Xcode nunca escreve em dados reais. `#if DEBUG` é uma **diretiva de compilação**: o código do outro ramo nem entra no binário.

### `month` como parâmetro, não como campo do corpo

`save(month:_:)` recebe o mês separado do `IncomeRequest` porque a API espera o mês na URL (`?month=yyyy-MM`) e só `{ "amount": ... }` no corpo.

### Consolidar não tem método próprio

A API não tem endpoint de consolidação. A web faz isso no cliente: cria o gasto consolidado e apaga os originais. O macOS segue o mesmo caminho, e essa orquestração fica no ViewModel ([Step 10](step-10-consolidate.md)), usando `create` e `delete` que já existem aqui.

### Dois tipos de erro, um por service (revertida)

A versão original deste step dava a cada service o seu próprio `enum ...Error`, pelo isolamento entre os dois recursos. Na prática isso deixou duas cópias idênticas de `validate`/`decode`, obrigaria o ViewModel a tratar dois tipos com os mesmos casos, e erros de rede (`URLError`) escapavam sem tipo de domínio. O [Step 04](step-04-app-error.md) explica a troca.

## Como o código funciona

### Operações

| Método | Chamada HTTP | Resposta |
|---|---|---|
| `ExpenseService.fetchExpenses(month:)` | `GET /expenses?month=yyyy-MM` | `[Expense]` |
| `ExpenseService.create(_:)` | `POST /expenses` | `Expense` (201) |
| `ExpenseService.update(id:_:)` | `PUT /expenses/{id}` | `Expense` |
| `ExpenseService.delete(id:)` | `DELETE /expenses/{id}` | sem corpo (204) |
| `IncomeService.fetch(month:)` | `GET /income?month=yyyy-MM` | `MonthlyIncome` |
| `IncomeService.save(month:_:)` | `PUT /income?month=yyyy-MM` | `MonthlyIncome` |

Renda não tem `create` nem `delete`: como só existe uma por mês, o `PUT` cobre "criar ou atualizar". Um mês sem renda registrada responde `amount: 0`, não 404.

### `async throws`

Todos os métodos são `async throws`:

- `async` indica que a função pode **suspender**: enquanto a rede não responde, a thread fica livre para outras tarefas (como manter a interface responsiva). Quem chama usa `await`.
- `throws` indica que a função pode falhar lançando um erro, que quem chama trata com `do`/`catch`.

```swift
let expenses = try await service.fetchExpenses(month: "2026-07")
```

### Anatomia de uma chamada

1. **Montar a URL.** `URLComponents` adiciona `?month=2026-07` com o escape correto, em vez de concatenar strings.
2. **Montar a requisição.** Para `POST`/`PUT`, um `URLRequest` com o método, o cabeçalho `Content-Type: application/json` e o corpo gerado por `JSONEncoder` a partir do `ExpenseRequest`.
3. **Enviar.** `try await session.data(for:)` devolve os bytes e a resposta.
4. **Validar.** O status precisa estar entre 200 e 299. `URLSession` não trata 404 ou 500 como erro: isso é responsabilidade do app.
5. **Decodificar.** `JSONDecoder` converte os bytes em `Expense`, `[Expense]` ou `MonthlyIncome`.

## Conexão com a próxima etapa

Os services funcionam, mas cada um trata erro do seu jeito e repete o mesmo código. Antes de o ViewModel começar a chamá-los, o [Step 04](step-04-app-error.md) unifica os erros em um `AppError` tipado e extrai a parte comum para um `APIClient`.
