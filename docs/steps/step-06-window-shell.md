# Step 06 — Janela, sidebar e primeira carga

## Objetivo

Até aqui o app tinha toda a lógica ([Step 05](step-05-dashboard-viewmodel.md)) e nenhuma tela. Este step monta a estrutura da janela e faz o app conversar com a API pela primeira vez:

- `HomeBudgetApp.swift` (alterado): cria o ViewModel e abre a janela.
- `Views/RootView.swift` (novo): janela dividida em sidebar e conteúdo.
- `Views/Dashboard/DashboardView.swift` (novo): a tela do mês, com seus quatro estados.
- `Views/Dashboard/MonthNavigatorView.swift` (novo): botões de mês anterior, próximo e "Hoje".
- `ContentView.swift` (removido): era o "Hello, world!" do template.
- `project.pbxproj`: permissão de rede para o app em sandbox.

Os gastos aparecem em uma lista simples e provisória. A tabela de verdade vem no Step 07.

## Decisões

### `NavigationSplitView` com uma única seção

A decisão de ter sidebar desde o início está no ADR do [Step 01](step-01-models.md). Aqui ela se concretiza: as seções são um `enum AppSection` com um caso só (`.budget`, "Orçamento"). Adicionar uma seção de análise depois será criar um caso novo e sua View; a navegação não muda.

### `Window` em vez de `WindowGroup`

| Opção | O que oferece | O que custa |
|---|---|---|
| `WindowGroup` (padrão do template) | Várias janelas, abas, ⌘N abre janela nova | Duas janelas do mesmo orçamento não fazem sentido, e ⌘N fica ocupado |
| `Window` (escolhida) | Uma única janela; ⌘N fica livre para "Novo gasto" | Não dá para comparar dois meses lado a lado |

Comparar meses é uma funcionalidade de análise futura e, quando vier, terá uma tela própria.

### O ViewModel pertence ao `App`

O `DashboardViewModel` é criado em `HomeBudgetApp` com `@State` e passado para baixo. Se fosse criado dentro de uma View, seria recriado sempre que o SwiftUI reconstruísse essa View, perdendo os dados. No `App`, ele vive enquanto o app estiver aberto.

### `.task(id:)` para carregar

```swift
.task(id: viewModel.month) {
    await viewModel.load()
}
```

| Opção | O que oferece | O que custa |
|---|---|---|
| `onAppear` + `Task { }` e outro `Task` em cada botão de mês | Controle manual | Cada lugar que muda o mês precisa lembrar de carregar; tarefas antigas continuam rodando |
| `.task(id:)` (escolhida) | Roda ao aparecer e **toda vez que `month` muda**; cancela a carga anterior sozinho | A carga fica ligada à vida da View |

Por isso os métodos de navegação do ViewModel só trocam o mês: a View reage à mudança. É também por isso que o ViewModel ignora o erro de requisição cancelada.

### Quatro estados explícitos

A tela é sempre exatamente uma destas: **erro**, **carregando**, **vazio** ou **conteúdo**. O `if/else if` em `DashboardView.content` garante que nunca apareçam dois ao mesmo tempo (uma tabela vazia com um spinner em cima, por exemplo). `ContentUnavailableView` é o componente do sistema para "não há o que mostrar", com ícone, título, descrição e ações.

"Carregando" só ocupa a tela quando **não há gastos para mostrar**. Ao atualizar um mês já carregado, os dados continuam visíveis.

### Permissão de rede no sandbox

O projeto tem App Sandbox ligado: o app roda isolado e só acessa o que declara. Sem declarar acesso de saída à rede, toda chamada à API falharia. A configuração de build `ENABLE_OUTGOING_NETWORK_CONNECTIONS = YES` faz o Xcode gerar o entitlement `com.apple.security.network.client`. É a mesma coisa que marcar "Outgoing Connections (Client)" em Signing & Capabilities.

| Opção | O que oferece | O que custa |
|---|---|---|
| Desligar o sandbox | Nenhuma permissão a declarar | O app perde o isolamento, que é exigido para distribuir na App Store |
| Declarar só o acesso de saída (escolhida) | O mínimo necessário: o app faz requisições, mas não aceita conexões | Uma linha de configuração |

## Como o código funciona

### `HomeBudgetApp.swift`

```swift
@main
struct HomeBudgetApp: App {
    @State private var viewModel = DashboardViewModel()

    var body: some Scene {
        Window("HomeBudget", id: "main") {
            RootView(viewModel: viewModel)
        }
        .defaultSize(width: 980, height: 680)
    }
}
```

`@main` marca o ponto de entrada do programa. `@State` faz o SwiftUI guardar o ViewModel fora da `struct` (que é recriada com frequência) e devolvê-lo sempre o mesmo.

### `RootView.swift`

`NavigationSplitView` recebe dois blocos: a sidebar (uma `List` das seções, com seleção ligada a `$section`) e o `detail`, que mostra a View da seção selecionada. O `$` cria um **binding**: uma ligação de leitura e escrita, que permite à lista alterar a variável `section`.

### `DashboardView.swift`

```swift
struct DashboardView: View {
    @Bindable var viewModel: DashboardViewModel
```

`@Bindable` permite criar bindings para propriedades de um objeto `@Observable` (`$viewModel.filter`, `$viewModel.selection`), usados a partir do Step 07.

O título da janela vem de `.navigationTitle(viewModel.monthTitle)`: como o ViewModel é observável, trocar o mês atualiza o título sozinho.

No estado de erro, o botão cria uma tarefa para poder chamar código assíncrono a partir de uma ação síncrona:

```swift
Button("Tentar novamente") {
    Task { await viewModel.load() }
}
```

### `MonthNavigatorView.swift`

Conforma a `ToolbarContent`, não a `View`: descreve itens de barra de ferramentas e onde cada um fica. As setas vão em `.navigation` (à esquerda, junto do título) e "Hoje" em `.primaryAction` (à direita).

Cada botão chama um método do ViewModel e tem um atalho:

| Ação | Atalho |
|---|---|
| Mês anterior | ⌘← |
| Próximo mês | ⌘→ |
| Hoje | ⌘T |

"Hoje" fica desabilitado quando o mês exibido já é o atual (`viewModel.isCurrentMonth`).

### O que foi conferido no app

- Abre no mês atual e lista os gastos vindos da API local.
- Próximo e anterior trocam o título e os dados; dezembro → janeiro vira o ano.
- "Hoje" volta ao mês atual.
- Mês sem gastos mostra "Nenhum gasto registrado neste mês".
- Com a API desligada: "Não foi possível carregar o mês" e "Tentar novamente", que carrega normalmente depois que a API volta.

## Conexão com a próxima etapa

A janela funciona, mas a lista de gastos é provisória. O [Step 07](step-07-expense-table.md) a substitui por uma tabela com colunas, ordenação, filtro por categoria, seleção e exclusão.
