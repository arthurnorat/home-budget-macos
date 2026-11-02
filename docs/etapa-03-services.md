# Etapa 3 — Services (ExpenseService + IncomeService)

## Objetivo desta etapa

Até aqui o app sabe *representar* um gasto/renda (Etapa 1) e sabe *formatar* esses dados para exibição (Etapa 2), mas nada ainda conversa com o backend. Esta etapa cria `HomeBudget/Services/ExpenseService.swift` e `HomeBudget/Services/IncomeService.swift` — a camada responsável por trocar dados com a API via `URLSession`, sem nenhuma biblioteca externa (mesma decisão do iOS).

Como nas etapas anteriores, ainda não há tela ou ViewModel chamando esses serviços — a verificação aqui é de compilação e de um teste manual (`curl`) contra a API real, não de uso dentro do app.

---

## Por que dois services (e por que cada um com seu próprio `enum ...Error`)

A API tem dois recursos independentes, `/expenses` e `/income`, sem relação entre si no contrato. Em vez de um `APIService` genérico cobrindo os dois, cada recurso ganha seu próprio service (`ExpenseService`/`IncomeService`) — e, seguindo o mesmo raciocínio, cada um define seu próprio `enum ...Error` em vez de compartilhar um tipo de erro genérico entre os dois. Isso é a mesma filosofia de "sem código compartilhado" que já rege a relação entre os clientes do projeto (ver `CLAUDE.md`): mesmo dentro de um único cliente, cada fatia de domínio fica isolada, então uma mudança em como `Income` trata erros nunca arrisca quebrar `Expense` (e vice-versa) — o preço (duas cópias quase idênticas de `validate`/`decode`) é pequeno perto do ganho de desacoplamento.

## `ExpenseService` — reaproveitado do iOS, com uma operação nova

Fonte: `~/iOS_Projects/HomeBudget/HomeBudget/Services/ExpenseService.swift`. A base é idêntica — `struct` (sem estado mutável), `init(baseURL:session:)` com valores padrão, `defaultBaseURL` com `#if DEBUG` (`localhost:8080` em dev / Cloud Run em produção), `enum ExpenseServiceError` e os helpers privados `validate`/`decode`. O raciocínio completo por trás dessas decisões já está na Etapa 3 do iOS (`~/iOS_Projects/HomeBudget/docs/etapa-03-service.md`) e continua valendo aqui sem alteração.

O que muda é a **cobertura de operações**, porque o macOS não é um app de lançamento rápido:

| Operação | Endpoint | iOS tem? |
|---|---|---|
| `fetchExpenses(month:)` | `GET /expenses?month=yyyy-MM` | sim |
| `create(_:)` | `POST /expenses` | sim |
| `update(id:_:)` | `PUT /expenses/{id}` | **não** — editar está fora do escopo mobile |
| `delete(id:)` | `DELETE /expenses/{id}` | sim |

`update(id:_:)` é a operação `create(_:)` com um detalhe a mais: o `id` vai na URL (`expenses/\(id)`), o método é `PUT` em vez de `POST`, mas o corpo é o mesmíssimo `ExpenseRequest` — por isso não existe (e não precisa existir) um `ExpenseUpdateRequest` separado, como já registrado na Etapa 1.

O backend chegou a ter um endpoint `POST /expenses/import-fixed` para copiar os gastos fixos do mês anterior, e este service tinha o método `importFixed(month:)` correspondente. A funcionalidade foi removida da API (e dos clientes) na virada para o Cloud Run, por ser pouco usada, e o método saiu daqui junto.

## `IncomeService` — novo, usa `MonthlyIncome`/`IncomeRequest`

Estrutura idêntica ao `ExpenseService` (mesmo padrão `struct`/`init`/`#if DEBUG`/`validate`/`decode`), só trocando o recurso:

```swift
func fetch(month: String) async throws -> MonthlyIncome {
    // GET /income?month=yyyy-MM
}

func save(month: String, _ request: IncomeRequest) async throws -> MonthlyIncome {
    // PUT /income?month=yyyy-MM
}
```

Dois detalhes que vêm direto do contrato da API e dos models da Etapa 1:

- **`month` é parâmetro da função, não campo do `IncomeRequest`.** O corpo do `PUT /income?month=yyyy-MM` é só `{"amount": ...}` — o mês vai na query string da URL, exatamente como `MonthlyIncome.swift`/`IncomeRequest.swift` já documentaram na Etapa 1 ("por que `IncomeRequest` só tem `amount`"). O service materializa essa decisão: `save(month:_:)` recebe o mês como argumento separado e monta a `URLComponents` com ele, do mesmo jeito que `fetchExpenses(month:)` já faz.
- **Não existe `create`/`delete` para renda.** O contrato só tem `GET`/`PUT` — `PUT` já cobre "criar ou atualizar" (não há distinção entre os dois casos, porque só pode existir uma renda por mês). Por isso `IncomeService` tem só duas funções, mais enxuto que `ExpenseService`.

## Por que consolidar gastos não aparece aqui

A funcionalidade "selecionar vários gastos e consolidar num só" (feature da web, prevista para a Etapa 9) **não tem endpoint próprio** na API — confirmado tanto no `CLAUDE.md` do backend quanto no código-fonte da web (`expense-table.ts`/`app.ts`, método `onConsolidate`): o Angular já faz isso client-side, chamando `create(_:)` para o gasto consolidado e `delete(id:)` para cada um dos originais selecionados. O `ExpenseService` do macOS já tem tudo que essa orquestração vai precisar — nada novo entra no service por causa disso, só vai aparecer como lógica no `DashboardViewModel` (Etapa 9).

---

## Verificação desta etapa

- **Build**: `xcodebuild -project HomeBudget.xcodeproj -scheme HomeBudget -configuration Debug build` → `BUILD SUCCEEDED`, sem erros.
- **Smoke test contra produção** (somente leitura, não escreve nada):
  ```
  curl "https://home-budget-api-wml2.onrender.com/expenses?month=2026-07"
  curl "https://home-budget-api-wml2.onrender.com/income?month=2026-07"
  ```
  (Na época esses endereços eram os da API no Render; hoje as mesmas rotas existem na URL do Cloud Run, `https://home-budget-api-689350097433.southamerica-east1.run.app`.)
  Confirma que o JSON real bate com `Expense`/`MonthlyIncome` (mesmos campos, mesmos nomes em camelCase), ou seja, `JSONDecoder().decode(...)` dentro de `fetchExpenses`/`fetch` decodifica essa resposta sem precisar de `CodingKeys` nem `dateDecodingStrategy` customizado.
- **`create`/`update`/`delete`/`save` não foram testados isoladamente** — chamar operações que escrevem sem UI para conferir o resultado não teria como ser verificado direito. O teste de ponta a ponta dessas operações acontece a partir da Etapa 4, quando o `DashboardViewModel` passar a chamar os services de verdade.

## Conectando com o restante do plano

- **Etapa 4 (`DashboardViewModel`)** vai instanciar `ExpenseService()` e `IncomeService()`, chamar `fetchExpenses(month:)`/`fetch(month:)` (com `Formatters.monthKey()`, Etapa 2) ao trocar de mês, e `create`/`update`/`delete`/`save` a partir das ações do usuário.
- **Etapa 9 (consolidar)** vai orquestrar `create`/`delete` no ViewModel para consolidar gastos selecionados.
