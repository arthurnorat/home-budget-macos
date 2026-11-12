# Step 10 — Consolidar gastos

## Objetivo

Juntar vários gastos em um só. O caso típico: cinco idas ao mercado no mês viram uma linha "Alimentação" com a soma, deixando o mês mais fácil de ler. É a última funcionalidade para a paridade com a web.

- `Views/Dashboard/ConsolidateView.swift` (novo): a sheet de confirmação.
- `Views/Dashboard/ExpenseTableView.swift` (alterado): botão e item de menu "Consolidar".
- `Views/Dashboard/DashboardView.swift` (alterado): apresenta a sheet.
- `ViewModels/DashboardViewModel.swift` (alterado): `ConsolidationDraft` passa a ser `Identifiable`.

A lógica (`consolidationDraft`, `canConsolidate`, `consolidate(description:)`) existe desde o [Step 05](step-05-dashboard-viewmodel.md). Este step dá a ela uma interface.

## Decisões

### As mesmas regras da web

| Campo do gasto consolidado | De onde vem |
|---|---|
| Valor | Soma dos selecionados |
| Data | A mais recente entre os selecionados |
| Categoria | A do primeiro selecionado |
| Descrição | A do primeiro selecionado, editável |

Os dois clientes operam sobre os mesmos dados; se consolidassem de formas diferentes, o resultado dependeria de onde o usuário clicou. Só a descrição é editável, como na web: valor, data e categoria são consequência da seleção.

"Primeiro" significa o primeiro na ordem da lista do ViewModel (data mais recente primeiro), não na ordem em que o usuário clicou nem na ordenação visual da tabela. É uma ordem estável, que não muda ao reordenar colunas.

### Sem endpoint próprio: várias chamadas, na ordem segura

A API não consolida. O app cria o gasto novo e depois exclui os originais, um por um. A ordem (criar primeiro) e o motivo estão no Step 05: uma falha no meio deixa um gasto duplicado, nunca dinheiro perdido.

| Opção | O que oferece | O que custa |
|---|---|---|
| Novo endpoint `POST /expenses/consolidate` na API | Operação atômica: tudo ou nada | Mudar o backend e os contratos de todos os clientes |
| Orquestrar no cliente (escolhida) | Nenhuma mudança na API; igual à web | Não é atômico: uma falha parcial precisa ser tratada |

A falha parcial é tratada assim: o ViewModel mostra o erro e **recarrega o mês**, de modo que a tela exibe exatamente o que ficou no servidor.

### Confirmação obrigatória, com prévia

Consolidar apaga gastos e não tem desfazer. A sheet mostra o que será criado (valor total, data, categoria) e quantos gastos serão substituídos, antes de qualquer chamada.

### A sheet fecha mesmo se falhar

No formulário de gasto (Step 08), uma falha mantém a sheet aberta para tentar de novo. Aqui é o contrário: depois de uma falha, parte dos gastos pode já ter sido apagada, e a prévia mostrada não corresponde mais à realidade. A sheet fecha, o alerta explica o erro e a tabela mostra o estado real.

### A prévia é capturada ao abrir

`DashboardView` guarda o `ConsolidationDraft` no momento do clique, e a sheet trabalha com essa cópia. A sheet é modal: enquanto está aberta, a seleção não muda, então a prévia e a operação se referem aos mesmos gastos.

## Como o código funciona

### Habilitando a ação

```swift
Button("Consolidar", systemImage: "arrow.triangle.merge") {
    onConsolidate()
}
.disabled(!viewModel.canConsolidate)
```

`canConsolidate` é verdadeiro com dois ou mais gastos selecionados. A barra de ações fica coerente com a seleção: com um gasto, "Editar" está ativo; com dois ou mais, "Consolidar"; "Excluir" vale para qualquer quantidade.

No menu de contexto, o item só aparece se o clique foi sobre duas ou mais linhas, e antes de abrir a sheet a seleção do ViewModel é igualada às linhas clicadas (`viewModel.selection = ids`).

### Apresentando a sheet

```swift
@State private var consolidationDraft: ConsolidationDraft?

.sheet(item: $consolidationDraft) { draft in
    ConsolidateView(viewModel: viewModel, draft: draft)
}

onConsolidate: { consolidationDraft = viewModel.consolidationDraft }
```

O mesmo padrão `sheet(item:)` do Step 08: a sheet existe enquanto houver um rascunho. `sheet(item:)` exige `Identifiable`, e o `id` do rascunho é montado a partir do seu conteúdo.

### `ConsolidateView`

Um `Form` com um `TextField` para a descrição e três `LabeledContent`, que mostram rótulo e valor somente leitura. O cabeçalho da seção diz "Consolidar 2 gastos" e o rodapé avisa que a ação não pode ser desfeita.

```swift
private func confirm() async {
    isSaving = true
    defer { isSaving = false }
    _ = await viewModel.consolidate(description: trimmedDescription)
    dismiss()
}
```

`defer` agenda um bloco para rodar quando a função terminar, por qualquer caminho. `_ =` descarta o `Bool` de propósito: a sheet fecha nos dois casos.

### O que acontece no ViewModel

```swift
let created = try await expenseService.create(request)
expenses = Self.sorted(expenses + [created])
for original in originals {
    try await expenseService.delete(id: original.id)
    expenses.removeAll { $0.id == original.id }
}
selection = []
```

Como a lista em memória é atualizada a cada chamada, os cards do resumo ([Step 09](step-09-income-summary.md)) acompanham. O total do mês não muda: a soma dos originais é exatamente o valor do consolidado.

### O que foi conferido no app

- Com um gasto selecionado, "Consolidar" fica desabilitado e "Editar" ativo; com dois, o inverso.
- "Mercado" (R$ 150,50, 10/11) e "Feira" (R$ 80,00, 09/11) selecionados: a sheet mostra "Consolidar 2 gastos", descrição "Mercado", R$ 230,50, 10/11/2026, Variável.
- Com a descrição trocada para "Alimentação", a tabela passa a ter uma única linha de R$ 230,50 e a seleção é limpa.
- A API local confirma: os dois originais sumiram, o consolidado existe e o total do mês é o mesmo de antes.

## Conexão com a próxima etapa

As cinco funcionalidades da Fase 1 estão prontas. O [Step 11](step-11-polish-release.md) cuida do acabamento (atualizar, tamanho da janela) e confere o build de Release contra a API de produção.
