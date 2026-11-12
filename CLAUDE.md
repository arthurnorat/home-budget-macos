# HomeBudget macOS

## Context

Household budget app shared between two users. The whole system (backend on Google Cloud Run + Firestore, web frontend on Vercel) is the source of truth for tracking and analyzing the budget.

**This is the system's main analysis client.** The iOS and Android apps exist only for quick expense entry, with no month navigation or editing. The macOS app is where the budget is analyzed, organized and planned. Its first phase mirrors the web version (same data model, same features); later it grows with analysis features the web does not have.

The API contract and the web app's context are imported here:

@/Users/arthurnorat/Java_Projects/home-budget-api/CLAUDE.md
@/Users/arthurnorat/Web_Development_Projects/home-budget-app/CLAUDE.md

## Stack

- **Swift + SwiftUI**, macOS, no external dependencies
- **URLSession** for HTTP
- **@Observable** for state
- **NavigationSplitView**: window with a sidebar, ready for future analysis sections

## Architecture

Simple MVVM. The rules between layers:

- **Views** (`Views/`) only draw state and forward user actions. They never call `URLSession` or a Service and contain no business logic.
- **ViewModels** (`ViewModels/`, `@Observable`) hold screen state, compute totals and orchestrate Services. They catch `AppError` and expose a user-facing message.
- **Services** (`Services/`) do the HTTP calls through `APIClient` and throw only `AppError` (`throws(AppError)`).
- **Models** (`Models/`) are plain values matching the API contract. Money is integer cents; dates are ISO strings.
- **Helpers** (`Helpers/`) are pure functions (formatting and parsing).

This project **shares no code** with the iOS app (no Swift Package, no synced copies). Each client keeps its own Models/Helpers/Services.

## Project-specific rules

These override the global rules, for this project only:

- **Claude builds this app end to end.** Claude compiles, starts the local API, runs every verification case (including driving the UI) and commits. Arthur studies the result afterwards.
- **Commits**: Claude commits one step at a time, straight to `main`, after the step is verified. **Never push**; Arthur pushes.
- **Gradual construction and documentation still apply**: one small, verified step at a time, each with its study document in `docs/steps/` (Portuguese).
- **UI text is in Portuguese** (for example `Category.displayName` returns "Fixo"/"Variável"). Identifiers, comments and commits stay in English.
- **Write tests only against the local API** (`http://localhost:8080` with the Firestore emulator). Production receives `GET` requests only.

## Design principle

Information-dense interface for someone who will spend time studying the budget:

- Neutral background, cards with a subtle border (same visual language as the web)
- System typography (SF Pro) and native controls
- Month navigation, expense editing and monthly income are the core of the app

## Features — Phase 1 (web parity)

1. Navigate by month (current, previous, next)
2. List the month's expenses, filtered by category (All/Fixed/Variable)
3. Create, edit and delete an expense
4. See and edit the monthly income, with the 50/30/20 targets against real totals
5. Consolidate several selected expenses into one

### Later (after web parity)

- Monthly evolution charts and month/year comparison
- Custom budget targets per category
- Exportable reports
- Categories beyond Fixed/Variable

## File organization

```
HomeBudget/
├── HomeBudgetApp.swift
├── Models/        Category, Expense, ExpenseRequest, MonthlyIncome, IncomeRequest, AppError
├── Helpers/       Formatters
├── Services/      APIClient, ExpenseService, IncomeService
├── ViewModels/    DashboardViewModel
└── Views/
    ├── RootView.swift
    ├── Dashboard/     DashboardView, MonthNavigatorView, ExpenseTableView, IncomeSummaryView, ConsolidateView
    └── ExpenseForm/   ExpenseFormView
docs/steps/        step-XX-name.md, one study document per step
```

## Infrastructure

The app itself has no infrastructure; it depends on the API's:

- **Debug builds** call `http://localhost:8080` (local API + Firestore emulator).
- **Release builds** call `https://home-budget-api-689350097433.southamerica-east1.run.app` (Cloud Run).
- The base URL lives in `Services/APIClient.swift`. No environment variables, no secrets: the API has no authentication yet.
- App Sandbox is on; the build setting `ENABLE_OUTGOING_NETWORK_CONNECTIONS` grants the network client entitlement.

## Out of scope

Besides the global defaults: the API and the other clients' repositories are read-only from here.

## Status

Current: step-11 done. Phase 1 (web parity) is complete: month navigation, expense table with filter, create/edit/delete, monthly income with the 50/30/20 summary and consolidation. Debug and Release builds verified.
Next: Phase 2, the analysis features (start with monthly evolution charts). Known debts are listed at the end of [step-11](docs/steps/step-11-polish-release.md).
