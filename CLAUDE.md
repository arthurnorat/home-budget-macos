# HomeBudget macOS

## Contexto do Projeto

App de controle de gastos domésticos compartilhado entre dois usuários. O sistema completo (backend em produção no Google Cloud Run + Firestore, frontend web no Vercel) é a fonte de verdade para controle e análise financeira.

**Este é o cliente principal de análise do sistema.** Ao contrário do iOS e do Android — que existem só para lançamento rápido do gasto do dia a dia, sem navegação por mês nem edição — o macOS é onde o orçamento é efetivamente **analisado, organizado, estudado e planejado**. Por isso, num primeiro momento, sua interface espelha a versão web (mesmo modelo de dados, mesmas funcionalidades de controle), e depois cresce com funcionalidades de análise que a web ainda não tem.

@import /Users/arthurnorat/Java_Projects/home-budget-api/CLAUDE.md
@import /Users/arthurnorat/Web_Development_Projects/home-budget-app/CLAUDE.md

## Stack macOS
- **Swift + SwiftUI** — interface declarativa
- **URLSession** — chamadas HTTP (sem bibliotecas externas, mesma decisão do iOS)
- **@Observable** — gerenciamento de estado (macOS 14+)
- **Arquitetura:** MVVM simples (View + ViewModel + Service), mesmo padrão do iOS
- **NavigationSplitView** — janela com sidebar, diferente da web (página única) e do iOS (tela única): já preparada para acomodar futuras seções de análise (Dashboard, Relatórios, etc.), mesmo que hoje só exista uma seção

## Relação com os outros clientes
Este projeto **não compartilha código** com o iOS (nem Swift Package, nem cópia manual sincronizada). Cada cliente mantém sua própria cópia de Models/Helpers/Services, do mesmo jeito que o Android não compartilha código com o iOS — os dois tendem a divergir conforme o macOS ganha funcionalidades exclusivas de análise que os apps mobile nunca terão.

## Princípio de Design
Interface densa em informação, pensada para quem vai passar tempo estudando o orçamento (não para lançar um gasto e sair):
- Fundo neutro, cards com borda sutil (mesma linguagem visual da web)
- Tipografia sistema (SF Pro)
- Janela com sidebar (`NavigationSplitView`) desde o início, para crescer sem precisar redesenhar a navegação depois
- Ao contrário do iOS/Android, aqui a navegação por mês, edição de gastos e renda mensal são o núcleo do app — é exatamente o oposto do escopo mobile

## Funcionalidades — Fase 1 (paridade com a web)
1. Navegar por mês (mês atual, anterior, próximo)
2. Listar gastos do mês, com filtro por categoria (Todos/Fixo/Variável)
3. Criar, editar e excluir gasto
4. Ver e editar a renda mensal, com resumo de metas 50/30/20 vs. totais reais por categoria
5. Consolidar múltiplos gastos selecionados em um só

### Fora do escopo imediato (visão de futuro, depois da paridade com a web)
- Gráficos de evolução mensal e comparação entre meses/anos
- Metas de orçamento customizáveis por categoria (além do 50/30/20 fixo)
- Relatórios exportáveis
- Categorias além de Fixo/Variável

## Organização de Arquivos (planejada)
```
HomeBudget/
├── Models/
│   ├── Category.swift
│   ├── Expense.swift
│   ├── ExpenseRequest.swift
│   ├── MonthlyIncome.swift
│   └── IncomeRequest.swift
├── Helpers/
│   └── Formatters.swift
├── Services/
│   ├── ExpenseService.swift
│   └── IncomeService.swift
├── ViewModels/
│   └── DashboardViewModel.swift
└── Views/
    ├── RootView.swift
    ├── Dashboard/
    │   ├── MonthNavigatorView.swift
    │   ├── ExpenseTableView.swift
    │   ├── ExpenseRowView.swift
    │   └── IncomeSummaryView.swift
    └── ExpenseForm/
        └── ExpenseFormView.swift
```

## Construção Gradual
Este projeto é construído uma etapa por vez, documentada em `docs/etapa-XX-nome.md` (objetivo → decisões explicadas com o "porquê" → verificação → conexão com a próxima etapa), no mesmo estilo didático usado no projeto iOS. Cada etapa é revisada e estudada antes de avançar para a próxima. **Apenas o usuário faz commits.**

## Status
Projeto Xcode criado e buildando (apenas arquivos padrão). Etapa 0 (contexto) concluída. Implementação dos arquivos customizados ainda não iniciada.
