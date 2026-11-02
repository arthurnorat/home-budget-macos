🇺🇸 [English](#english) · 🇧🇷 [Português](#português)

---

<a name="english"></a>

# 💰 HomeBudget macOS

Native macOS client for HomeBudget, the household budget system — built as the primary tool for browsing, analyzing, and planning the budget.

## About

Unlike the iOS and Android companion apps, which only support quick expense entry on the go, HomeBudget macOS mirrors the web dashboard's full feature set (month navigation, editing, income tracking, 50/30/20 summary) and will grow beyond it with dedicated analysis features not available anywhere else yet.

## Features

- Browse expenses month by month *(in development)*
- Create, edit, and delete expenses *(in development)*
- Monthly income and 50/30/20 budget summary *(in development)*
- Consolidate selected expenses *(planned)*

## Tech Stack

- **Swift** · SwiftUI · macOS 14+
- **Architecture**: MVVM
- **Networking**: URLSession (no external dependencies)
- **State management**: `@Observable`
- **Navigation**: `NavigationSplitView`

## Status

In early development, built incrementally, one step at a time — see `docs/etapa-*.md` for the step-by-step build log.

---

<a name="português"></a>

# 💰 HomeBudget macOS

Cliente macOS nativo do HomeBudget, o sistema de orçamento doméstico — construído como a principal ferramenta para navegar, analisar e planejar o orçamento.

## Sobre

Diferente dos apps companheiros iOS e Android, que servem apenas para lançamento rápido de gastos, o HomeBudget macOS espelha todas as funcionalidades do dashboard web (navegação por mês, edição, controle de renda, resumo 50/30/20) e vai crescer além dela com funcionalidades de análise dedicadas que ainda não existem em nenhum outro cliente.

## Funcionalidades

- Navegar pelos gastos mês a mês *(em desenvolvimento)*
- Criar, editar e excluir gastos *(em desenvolvimento)*
- Renda mensal e resumo de orçamento 50/30/20 *(em desenvolvimento)*
- Consolidar gastos selecionados *(planejado)*

## Tecnologias

- **Swift** · SwiftUI · macOS 14+
- **Arquitetura**: MVVM
- **Rede**: URLSession (sem dependências externas)
- **Gerenciamento de estado**: `@Observable`
- **Navegação**: `NavigationSplitView`

## Status

Em desenvolvimento inicial, construído de forma incremental, uma etapa por vez — veja `docs/etapa-*.md` para o histórico de construção etapa a etapa.
