# Step 02 — Formatters

## Objetivo

Os models do [Step 01](step-01-models.md) guardam os dados como a API os representa: `amount` em centavos (`Int`), datas como `String` ISO (`"2026-07-27"`), mês como `"2026-07"`. Isso é ótimo para transportar e péssimo para exibir: ninguém quer ler "155000" onde deveria estar "R$ 1.550,00".

`HomeBudget/Helpers/Formatters.swift` faz essa ponte com funções puras de conversão, nos dois sentidos: do dado cru para o texto exibido, e do texto digitado de volta para o dado cru.

## Decisões

### `enum` sem casos como namespace

| Opção | O que oferece | O que custa |
|---|---|---|
| Funções globais soltas | Nada a escrever além das funções | Poluem o escopo global; `currency(...)` não diz de onde vem |
| `struct`/`class` com métodos | Agrupa as funções | Permite `Formatters()`, uma instância sem sentido, já que não há estado |
| `enum Formatters` sem casos (escolhida) | Agrupa as funções e **não pode ser instanciado** | Nenhum |

Um `enum` sem casos não tem valores possíveis, então o compilador impede `Formatters()`. Sobra só o uso pretendido: `Formatters.currency(fromCents: 1550)`.

### Formatters em cache (`static let`)

Criar um `DateFormatter` é caro: ele carrega dados de locale e calendário. Criar um novo a cada célula da tabela pesaria na rolagem. Cada formatter é criado uma única vez, como `private static let`, e reaproveitado. O `static let` em Swift é inicializado sob demanda e de forma segura entre threads.

### `en_US_POSIX` para formatos de máquina, `pt_BR` para texto humano

`"yyyy-MM-dd"` e `"yyyy-MM"` são formatos fixos da API, não texto para pessoas. Com o locale do sistema, um usuário com calendário budista ou relógio de 12 horas poderia ver o parse falhar ou produzir outro ano. `en_US_POSIX` é o locale que a Apple recomenda para formatos fixos: ele não muda com as preferências do usuário.

`pt_BR` fica só nos dois formatters que geram texto para leitura: a moeda ("R$ 1.550,00") e o mês por extenso ("julho de 2026").

### `Decimal` para dividir centavos

`currency(fromCents:)` converte os centavos para `Decimal` antes de dividir por 100. `Decimal` representa frações decimais exatamente, ao contrário de `Double`. Para valores pequenos a diferença não aparece, mas a regra "dinheiro nunca passa por `Double` na exibição" evita ter de pensar no assunto.

### Parse com falha devolve o texto original

`displayDate(fromISO:)`, `shiftMonth` e `displayMonth` devolvem a entrada intacta se ela não puder ser interpretada. A alternativa seria lançar erro ou devolver `nil`, o que obrigaria cada View a tratar um caso que só acontece se a API enviar um dado malformado. Mostrar o texto cru é um degradar aceitável e nunca derruba o app.

### `shiftMonth` com `Calendar`, não com aritmética manual

Somar meses à mão exige tratar a virada de ano (`if month == 12`, `if month == 1`). `Calendar.current.date(byAdding: .month, ...)` já resolve: janeiro menos um mês vira dezembro do ano anterior. Menos código e nenhum caso especial para errar.

## Como o código funciona

### Os cinco formatters

```swift
private static let isoDateFormatter      // "yyyy-MM-dd"      en_US_POSIX
private static let displayDateFormatter  // "dd/MM/yyyy"      en_US_POSIX
private static let monthKeyFormatter     // "yyyy-MM"         en_US_POSIX
private static let monthDisplayFormatter // "MMMM 'de' yyyy"  pt_BR
private static let currencyFormatter     // moeda             pt_BR
```

Cada um é declarado com um *closure* executado na hora: `= { ...; return formatter }()`. É a forma idiomática de criar e configurar um objeto em uma única expressão.

No formato `"MMMM 'de' yyyy"`, `MMMM` é o nome completo do mês e as aspas simples marcam texto literal: sem elas, o `d` de "de" seria lido como "dia do mês".

### Dinheiro

```swift
Formatters.currency(fromCents: 155000)   // "R$ 1.550,00"
Formatters.parseAmountToCents("15,50")   // 1550
Formatters.parseAmountToCents("abc")     // nil
Formatters.parseAmountToCents("-3")      // nil
```

`parseAmountToCents` remove espaços, troca vírgula por ponto, converte para número, rejeita negativos e arredonda para centavos. Devolve `Int?` (opcional): `nil` significa "isso não é um valor válido", e quem chama decide o que fazer (o formulário desabilita o botão de salvar).

### Datas

```swift
Formatters.displayDate(fromISO: "2026-07-27")  // "27/07/2026"
Formatters.isoDateString(from: Date())          // "2026-11-12"
```

A primeira é usada na tabela; a segunda, ao montar um `ExpenseRequest` a partir do `DatePicker`.

### Mês

```swift
Formatters.monthKey()                     // "2026-11" (mês atual)
Formatters.shiftMonth("2026-01", by: -1)  // "2025-12"
Formatters.shiftMonth("2026-12", by: 1)   // "2027-01"
Formatters.displayMonth("2026-07")        // "julho de 2026"
```

`shiftMonth` reaproveita o `monthKeyFormatter` nos dois sentidos: interpreta `"2026-01"` como `Date`, pede ao `Calendar` a data deslocada e formata de volta. `displayMonth` interpreta com o `monthKeyFormatter` e formata com o `monthDisplayFormatter`.

## Conexão com a próxima etapa

Com dados e formatação prontos, falta buscar e enviar esses dados. O [Step 03](step-03-services.md) cria os Services, que usam `monthKey` para montar `?month=yyyy-MM` e trocam `Expense`/`MonthlyIncome` com a API.
