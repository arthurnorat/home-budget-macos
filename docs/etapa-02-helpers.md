# Etapa 2 — Helpers/Formatters.swift

## Objetivo desta etapa

Os models da Etapa 1 guardam os dados "crus", exatamente como a API os representa: `amount` em centavos (`Int`), datas como `String` ISO (`"2026-07-27"`), mês como `String` (`"2026-07"`). Isso é ótimo para transportar e decodificar, mas péssimo para mostrar na tela — ninguém quer ver "155000" onde deveria estar "R$ 1.550,00".

A camada de **Helpers** faz essa ponte: um único arquivo, `Formatters.swift`, com funções puras de conversão. Nada aqui ainda é usado por uma tela — assim como na Etapa 1, construímos a camada, confirmamos que compila, e só depois empilhamos a próxima (Services, na Etapa 3).

## O que foi reaproveitado do iOS

`enum Formatters` inteiro veio quase sem alteração de `~/iOS_Projects/HomeBudget/HomeBudget/Helpers/Formatters.swift`:

- **`enum` em vez de `struct`/`class`**: não existe estado por instância, só funções de conversão — um namespace estático.
- **`DateFormatter`/`NumberFormatter` cacheados como `static let` privados**: criar um `DateFormatter` é uma operação cara (parsing de locale, calendário); cachear evita refazer esse trabalho a cada chamada.
- **`en_US_POSIX` para os formatters de *parsing* de máquina** (`isoDateFormatter`, `displayDateFormatter`, `monthKeyFormatter`): datas ISO e `dd/MM/yyyy` não são texto para humanos, são formato fixo — usar o locale do dispositivo aqui poderia quebrar o parse se o usuário tiver um locale exótico. `pt_BR` fica reservado só para o que é de fato exibido em português (moeda e, agora, o mês por extenso).
- **`currency(fromCents:)` via `Decimal`, não `Double`**: evita erro de ponto flutuante ao dividir centavos por 100 antes de formatar.
- **`parseAmountToCents(_:)` aceita vírgula**: o usuário digita "15,50" (padrão BR), a função normaliza para ponto antes de converter para `Double`.

Essas funções (`currency`, `displayDate`, `isoDateString`, `monthKey`, `parseAmountToCents`) são idênticas às do iOS — o contrato de dados é o mesmo, então a conversão também é.

## O que é novo — funções que só o macOS precisa

O iOS nunca navega por mês: o app de lançamento rápido só trabalha com "hoje" (`monthKey(from: Date())` sempre com o valor padrão). O macOS, sendo o cliente de análise, tem um navegador de mês (◀ julho de 2026 ▶) como uma das telas centrais — por isso precisa de duas funções que o iOS nunca teve motivo para escrever.

### `shiftMonth(_ monthKey: String, by delta: Int) -> String`

Usada pelos botões ◀/▶: dado `"2026-07"` e `delta: -1`, devolve `"2026-06"`.

Em vez de criar um formatter novo só para isso, ela reaproveita o `monthKeyFormatter` que já existia (até então só usado para formatar `Date → "yyyy-MM"` em `monthKey(from:)`) — agora também no sentido inverso, parseando `"yyyy-MM" → Date`. Fazer `Calendar.current.date(byAdding: .month, ...)` sobre esse `Date` e formatar de volta lida corretamente com virada de ano (dezembro − 1 mês → novembro do mesmo ano; janeiro − 1 mês → dezembro do ano anterior) sem nenhuma lógica manual de "if month == 1".

Se o parse falhar (string mal formada), a função devolve o `monthKey` original — mesmo padrão defensivo que `displayDate(fromISO:)` já usa, evitar crash por causa de dado inesperado.

### `displayMonth(_ monthKey: String) -> String`

Usada no texto central do navegador de mês: dado `"2026-07"`, devolve `"julho de 2026"` — mesmo formato que a web já usa (`month-navigator.ts`, `date.toLocaleDateString('pt-BR', { month: 'long', year: 'numeric' })`).

Implementada com um `DateFormatter` novo, `monthDisplayFormatter` (locale `pt_BR`, `dateFormat = "MMMM 'de' yyyy"`), que só existe para gerar texto — nunca para fazer parse. Por isso ele é o único formatter do arquivo com locale `pt_BR`, ao lado do `currencyFormatter`; todos os outros usam `en_US_POSIX` porque fazem parsing de máquina.

## Conectando com o restante do plano

- **Etapa 3 (Services)** vai usar `isoDateString(from:)` e `monthKey(from:)` para montar query params (`?month=yyyy-MM`) e corpos de requisição (`ExpenseRequest.date`).
- **Etapa 6 (Dashboard)**: a `MonthNavigatorView` vai chamar `shiftMonth` diretamente nos botões ◀/▶ e `displayMonth` no label central; a `ExpenseTableView`/`ExpenseRowView` vão usar `currency(fromCents:)` e `displayDate(fromISO:)` para exibir cada gasto.
- **Etapa 7 (Formulário de gasto)** vai usar `parseAmountToCents(_:)` para converter o texto digitado pelo usuário de volta para centavos antes de montar um `ExpenseRequest`.

## Verificação desta etapa

Abrir o Xcode, confirmar que `Formatters.swift` aparece em `HomeBudget/Helpers/` no navegador de arquivos (grupo sincronizado, mesmo comportamento de `Models`) e rodar Build (⌘B). Como nenhuma tela ou service ainda referencia `Formatters`, a verificação por enquanto é só confirmar que compila sem erros nem warnings antes de seguir para a Etapa 3 (Services).
