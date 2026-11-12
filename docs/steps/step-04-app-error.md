# Step 04 — AppError e APIClient

## Objetivo

O [Step 03](step-03-services.md) deixou dois services funcionando, mas com três problemas que o ViewModel herdaria:

1. Dois tipos de erro com os mesmos casos (`ExpenseServiceError`, `IncomeServiceError`).
2. Falhas de rede (`URLError`) escapavam cruas, sem tipo de domínio.
3. O mesmo código de validar status e decodificar JSON existia em dois arquivos.

Este step resolve os três antes de qualquer tela existir:

- `HomeBudget/Models/AppError.swift` (novo): o único tipo de erro do app.
- `HomeBudget/Services/APIClient.swift` (novo): o único lugar que fala HTTP.
- `ExpenseService.swift` e `IncomeService.swift` (reescritos): passam a descrever só *o que* chamar.

## Decisões

### Um tipo de erro para o app inteiro

| Opção | O que oferece | O que custa |
|---|---|---|
| Um `enum` por service (Step 03) | Cada recurso isolado | Casos duplicados; o ViewModel trata dois tipos iguais; `URLError` fica de fora |
| `AppError` único (escolhida) | Um só `switch` cobre todas as falhas; uma só tradução para mensagem ao usuário | Um caso específico de um recurso apareceria para todos |

Os dois recursos falham exatamente das mesmas formas (sem rede, status ruim, JSON inesperado). O isolamento do Step 03 protegia contra uma divergência que não existe.

### `throws(AppError)`: erros tipados

Em Swift, `throws` simples significa "pode lançar **qualquer** `Error`". Quem chama precisa de um `catch` genérico no final, e o compilador não ajuda a saber o que realmente pode vir.

`throws(AppError)` (disponível desde o Swift 6) declara o tipo exato do erro:

```swift
func fetchExpenses(month: String) async throws(AppError) -> [Expense]
```

Duas consequências práticas:

- Dentro de um `catch`, a variável `error` já é um `AppError`, sem `as?`.
- Dentro da função, o compilador **recusa** lançar outro tipo. Foi isso que obrigou a converter `URLError` e os erros do `JSONDecoder`: deixar um deles escapar não compila.

O custo: toda falha precisa ser convertida para um caso de `AppError` na fronteira. É exatamente o trabalho que o `APIClient` concentra.

### `APIClient` compartilhado em vez de duplicar nos services

| Opção | O que oferece | O que custa |
|---|---|---|
| Cada service monta e valida suas requisições | Services independentes | A conversão de erros existiria em dois lugares, e os dois precisariam mudar juntos |
| `APIClient` usado pelos dois (escolhida) | Conversão de erros, URL base e JSON em um só lugar; cada método do service vira uma linha | Um tipo a mais; os services passam a depender dele |
| Um service único para tudo | Menos arquivos | Mistura `/expenses` e `/income` |

Os services continuam separados por recurso (decisão mantida do Step 03). O que foi unificado é só o mecanismo HTTP.

### `case network(URLError)` guarda o erro original

O caso carrega o `URLError` para que, no futuro, o app possa distinguir "sem internet" de "tempo esgotado" sem mudar o tipo. Hoje a mensagem ao usuário é a mesma para todos.

### A mensagem ao usuário mora no erro

`AppError.userMessage` traduz cada caso para português. Alternativa: cada ViewModel ter seu próprio `switch`. Com um só tipo de erro, a tradução também pode ser uma só, e uma tela nova já nasce com as mensagens certas. O `switch` não tem `default`: se um caso novo for criado, o compilador exige a mensagem dele.

## Como o código funciona

### `AppError.swift`

```swift
enum AppError: Error, Equatable {
    case network(URLError)
    case invalidResponse
    case server(statusCode: Int)
    case decoding
    case encoding
}
```

Os casos com parênteses têm **valores associados**: `.server(statusCode: 404)` carrega o número junto. No `switch`, `case .server(let statusCode) where statusCode == 404` extrai o valor e ainda filtra por ele, o que permite dar mensagens diferentes para 404, outros 4xx e 5xx.

| Situação | Caso | Mensagem |
|---|---|---|
| API desligada, sem internet | `.network` | "Não foi possível conectar ao servidor…" |
| Editar um gasto já excluído | `.server(statusCode: 404)` | "Este registro não existe mais no servidor." |
| Dados recusados (400, 422) | `.server(statusCode: 4xx)` | "O servidor recusou os dados enviados…" |
| Falha do servidor (500, 503) | `.server(statusCode: 5xx)` | "O servidor está com problemas…" |
| JSON diferente do model | `.decoding` | "Não foi possível interpretar os dados…" |

### `APIClient.swift`

Três métodos públicos, um por formato de chamada:

```swift
func get<Response: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws(AppError) -> Response
func send<Body: Encodable, Response: Decodable>(_ method: String, _ path: String, query: [URLQueryItem] = [], body: Body) async throws(AppError) -> Response
func delete(_ path: String) async throws(AppError)
```

`<Response: Decodable>` é um **genérico**: a função funciona para qualquer tipo decodificável, e o Swift descobre qual pelo tipo de retorno de quem chama. Em `ExpenseService.fetchExpenses`, o retorno é `[Expense]`, então `Response` vira `[Expense]`.

Por baixo, três funções privadas:

- `makeRequest` monta a URL (`baseURL` + caminho + query) e define o método.
- `perform` envia e valida. É aqui que os erros são convertidos:

  ```swift
  do {
      (data, response) = try await session.data(for: request)
  } catch let error as URLError {
      throw .network(error)
  } catch {
      throw .network(URLError(.unknown))
  }
  ```

  Como a função é `throws(AppError)`, basta escrever `throw .network(error)`: o Swift já sabe que o tipo é `AppError`. Depois vêm as duas verificações com `guard`: a resposta precisa ser HTTP e o status precisa estar entre 200 e 299.
- `decode` converte os bytes no tipo pedido e transforma qualquer falha em `.decoding`.

O `#if DEBUG` com a URL base, antes repetido nos dois services, agora existe só aqui.

### Os services depois da mudança

```swift
struct ExpenseService {
    private let client: APIClient

    func fetchExpenses(month: String) async throws(AppError) -> [Expense] {
        try await client.get("expenses", query: [URLQueryItem(name: "month", value: month)])
    }

    func delete(id: String) async throws(AppError) {
        try await client.delete("expenses/\(id)")
    }
    // create, update: uma linha cada
}
```

Cada método é a tradução direta de uma linha do contrato da API. `ExpenseService.swift` caiu de 84 para 26 linhas.

### Comportamento real da API

Conferido contra a API local, e relevante para as mensagens:

| Chamada | Status |
|---|---|
| `POST /expenses` válido | 201 |
| `POST /expenses` com descrição vazia ou valor ≤ 0 | 422 |
| `PUT /expenses/{id}` com id que não é UUID | 400 |
| `DELETE /expenses/{id}` de gasto inexistente | 404 |
| `GET /income` de mês sem renda | 200 com `amount: 0` |

## Conexão com a próxima etapa

Com services que lançam um único tipo de erro, o ViewModel pode ser escrito com um tratamento uniforme: todo `catch` recebe um `AppError` e guarda `error.userMessage`. O [Step 05](step-05-dashboard-viewmodel.md) cria o `DashboardViewModel`.
