🇺🇸 [English](#english) · 🇧🇷 [Português](#português)

---

<a name="english"></a>

# 💰 HomeBudget macOS

Native macOS client for HomeBudget, the household budget system — built as the primary tool for browsing, analyzing, and planning the budget.

## About

Unlike the iOS and Android companion apps, which only support quick expense entry on the go, HomeBudget macOS mirrors the web dashboard's full feature set (month navigation, editing, income tracking, 50/30/20 summary) and will grow beyond it with dedicated analysis features not available anywhere else yet.

## Features

- Browse expenses month by month, with year rollover and a shortcut back to the current month
- Sortable expense table with a category filter (All / Variable / Fixed)
- Create, edit and delete expenses
- Monthly income with the 50/30/20 budget targets compared against real spending
- Consolidate several selected expenses into one

## Tech Stack

- **Swift** · SwiftUI · macOS
- **Architecture**: MVVM (Views → `@Observable` ViewModel → Services)
- **Networking**: URLSession with typed errors (`throws(AppError)`), no external dependencies
- **Navigation**: `NavigationSplitView`

## Running

Open `HomeBudget.xcodeproj` in Xcode and run the `HomeBudget` scheme.

- **Debug** builds call the API at `http://localhost:8080`, so the HomeBudget API must be running locally.
- **Release** builds call the production API on Google Cloud Run.

## Keyboard shortcuts

| Action | Shortcut |
|---|---|
| New expense | ⌘N |
| Previous / next month | ⌘← / ⌘→ |
| Current month | ⌘T |
| Refresh | ⌘R |
| Edit the selected expense | Return or double click |
| Delete the selected expenses | ⌫ |

## Status

Web parity reached: every feature of the web dashboard is available. Analysis features (charts, month comparison, reports) come next.

The app was built one step at a time. Each step has a study document in `docs/steps/` (written in Portuguese) explaining what was built and why.

---

<a name="português"></a>

# 💰 HomeBudget macOS

Cliente macOS nativo do HomeBudget, o sistema de orçamento doméstico — construído como a principal ferramenta para navegar, analisar e planejar o orçamento.

## Sobre

Diferente dos apps companheiros iOS e Android, que servem apenas para lançamento rápido de gastos, o HomeBudget macOS espelha todas as funcionalidades do dashboard web (navegação por mês, edição, controle de renda, resumo 50/30/20) e vai crescer além dela com funcionalidades de análise dedicadas que ainda não existem em nenhum outro cliente.

## Funcionalidades

- Navegar pelos gastos mês a mês, com virada de ano e atalho para voltar ao mês atual
- Tabela de gastos ordenável, com filtro por categoria (Todos / Variável / Fixo)
- Criar, editar e excluir gastos
- Renda mensal com as metas 50/30/20 comparadas ao gasto real
- Consolidar vários gastos selecionados em um só

## Tecnologias

- **Swift** · SwiftUI · macOS
- **Arquitetura**: MVVM (Views → ViewModel `@Observable` → Services)
- **Rede**: URLSession com erros tipados (`throws(AppError)`), sem dependências externas
- **Navegação**: `NavigationSplitView`

## Como rodar

Abra `HomeBudget.xcodeproj` no Xcode e rode o scheme `HomeBudget`.

- Builds de **Debug** chamam a API em `http://localhost:8080`, então a API do HomeBudget precisa estar rodando localmente.
- Builds de **Release** chamam a API de produção no Google Cloud Run.

## Atalhos de teclado

| Ação | Atalho |
|---|---|
| Novo gasto | ⌘N |
| Mês anterior / próximo | ⌘← / ⌘→ |
| Mês atual | ⌘T |
| Atualizar | ⌘R |
| Editar o gasto selecionado | Return ou duplo clique |
| Excluir os gastos selecionados | ⌫ |

## Status

Paridade com a web alcançada: todas as funcionalidades do dashboard web estão disponíveis. As funcionalidades de análise (gráficos, comparação entre meses, relatórios) vêm a seguir.

O app foi construído uma etapa por vez. Cada etapa tem um documento de estudo em `docs/steps/` (em português) explicando o que foi construído e por quê.
