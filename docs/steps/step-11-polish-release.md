# Step 11 — Acabamento e build de Release

## Objetivo

Fechar a Fase 1. As cinco funcionalidades já existiam; este step cuida do que separa "funciona" de "pronto para uso":

- Botão **Atualizar** (⌘R), para ver o que o outro usuário lançou.
- **Tamanho mínimo** da janela.
- Erro de salvar exibido **dentro do formulário** (correção de um defeito encontrado na verificação).
- Valores editáveis com **separador de milhar** ("6.000,00" em vez de "6000,00").
- Conferência do build de **Release** contra a API de produção.
- `README.md` e `CLAUDE.md` atualizados.

Arquivos alterados: `DashboardView.swift`, `RootView.swift`, `ExpenseFormView.swift`, `DashboardViewModel.swift`, `Formatters.swift`.

## Decisões

### Atualizar manual, sem atualização automática

Duas pessoas usam o mesmo orçamento, então os dados podem mudar por fora do app.

| Opção | O que oferece | O que custa |
|---|---|---|
| Buscar de tempos em tempos (polling) | Dados sempre recentes | Chamadas constantes à API, quase sempre para nada; a tabela pode mudar enquanto o usuário seleciona linhas |
| Atualização em tempo real | Mudanças aparecem na hora | Exigiria outra tecnologia na API (WebSocket ou listeners do Firestore) |
| Botão Atualizar + recarga a cada troca de mês (escolhida) | Simples e previsível: os dados mudam quando o usuário pede | O usuário pode estar vendo dados de alguns minutos atrás |

Para duas pessoas lançando alguns gastos por dia, o botão resolve. Ao atualizar um mês que já tem dados, eles continuam na tela durante a busca (o estado "carregando" de tela cheia só aparece sem dados).

### Erro de salvar dentro do formulário

A versão original do [Step 08](step-08-expense-form.md) reportava a falha pelo alerta geral da tela (`actionError`). Na verificação, com a API desligada, clicar em "Adicionar" **não mostrava nada**: o formulário ficava aberto, sem explicação. O alerta só aparecia depois de cancelar.

A causa: no macOS, um alerta é apresentado como sheet da janela, e uma janela mostra **uma sheet por vez**. Com o formulário (que já é uma sheet) aberto, o alerta entrava na fila.

| Opção | O que oferece | O que custa |
|---|---|---|
| Fechar o formulário e então mostrar o alerta | Mantém um só mecanismo de erro | O usuário perde o que digitou |
| Um segundo alerta, apresentado pelo próprio formulário | Aparece na hora | Dois alertas ligados ao mesmo estado; fácil reintroduzir a fila |
| Mensagem no rodapé do formulário (escolhida) | Aparece na hora, ao lado do que precisa ser corrigido; o texto digitado é preservado | `save` passa a devolver a mensagem (`String?`) em vez de `Bool` |

Os outros erros de ação (excluir, salvar renda, consolidar) continuam no alerta geral, porque acontecem sem nenhuma sheet aberta. Na consolidação, a sheet fecha antes, de propósito ([Step 10](step-10-consolidate.md)).

Este é o tipo de defeito que só aparece exercitando o caminho de erro na interface: o teste da lógica ([Step 05](step-05-dashboard-viewmodel.md)) passava, porque `actionError` era preenchido corretamente. O problema estava em *onde* ele era exibido.

### Tamanho mínimo da janela

`RootView` declara `.frame(minWidth: 860, minHeight: 520)`. Abaixo disso, os quatro cards do resumo e as colunas da tabela não cabem. O tamanho inicial (980 × 680) continua vindo de `.defaultSize` no `App`, e o sistema lembra o último tamanho usado.

### Mesmo texto para exibir e para editar valores

`amountText(fromCents:)` passou a usar um `NumberFormatter` decimal em `pt_BR`, com duas casas: `600000` vira `"6.000,00"`. Como `parseAmountToCents` trata o ponto como separador de milhar quando há vírgula, o texto gerado é lido de volta sem perda. Isso foi conferido abrindo um gasto de R$ 1.234,56 e salvando sem alterar: a API continuou com `123456`.

## Como o código funciona

### Atualizar

```swift
ToolbarItem(placement: .primaryAction) {
    Button("Atualizar", systemImage: "arrow.clockwise") {
        Task { await viewModel.load() }
    }
    .keyboardShortcut("r", modifiers: .command)
    .disabled(viewModel.isLoading)
}
```

Chama o mesmo `load()` da troca de mês. `load()` preserva a seleção das linhas que continuam existindo (`selection.intersection(...)`) e descarta a das que sumiram.

### Erro no formulário

No ViewModel:

```swift
func save(_ request: ExpenseRequest, editing: Expense? = nil) async -> String? {
    do {
        // ...create ou update, atualiza a lista...
        return nil
    } catch {
        return error.userMessage
    }
}
```

No formulário:

```swift
@State private var errorMessage: String?

errorMessage = await viewModel.save(request, editing: editing)
if errorMessage == nil {
    dismiss()
}
```

A mensagem aparece no rodapé da seção, com um `Label` (ícone + texto) em vermelho. Uma nova tentativa substitui a mensagem; um sucesso fecha a sheet.

### Ícone do app

O ícone é a mesma arte do app iOS (cifrão branco sobre verde), para os dois clientes serem reconhecidos como o mesmo produto. A arte do iOS é um quadrado de 1024 px sem transparência, porque o iOS recorta os cantos sozinho. No macOS o ícone precisa vir pronto: um quadrado arredondado de 824 px centralizado em uma tela de 1024 px, com margem transparente. Sem isso, o ícone apareceria maior que os vizinhos no Dock e com cantos retos.

A partir dessa versão ajustada foram gerados os sete arquivos que o catálogo de assets pede (16, 32, 64, 128, 256, 512 e 1024 px), em `Assets.xcassets/AppIcon.appiconset/`. Cada tamanho em pontos tem uma versão 1x e outra 2x (para telas Retina), e alguns arquivos servem a dois lugares: o de 32 px é tanto "16 pt @2x" quanto "32 pt @1x".

## Verificação da Fase 1

Conferido no app em Debug, contra a API local com o emulador do Firestore:

| Camada | Casos |
|---|---|
| Caminho feliz | Navegar entre meses; criar, editar, excluir; salvar renda; consolidar dois gastos; atualizar |
| Persistência | Cada escrita conferida direto na API local; dados continuam ao reabrir o app |
| Bordas | Mês vazio; renda zero; dezembro → janeiro; valor com milhar ("1.234,56"); gasto criado por fora aparece ao atualizar |
| Erros | API desligada ao abrir (tela de erro + "Tentar novamente"); API desligada ao salvar (mensagem no formulário, dados preservados, nova tentativa funciona); valor inválido não habilita o botão; excluir algo já excluído responde 404 com mensagem própria |
| Regressão | Fluxos anteriores repetidos depois de cada step e no build final |

Em **Release**, o app foi aberto apenas para leitura: mostrou a renda e a lista (vazia) do mês atual em produção, iguais ao que a API de produção responde. Nenhuma escrita foi feita em produção.

Não foi possível exercitar por automação, porque dependem do app em primeiro plano: os atalhos de teclado (⌘N, ⌘R, ⌘←, ⌘→, ⌘T, ⌫, Return), o duplo clique, o menu de contexto e a troca de data pelo `DatePicker`. As ações que eles disparam foram testadas pelos botões equivalentes.

## Dívidas técnicas e riscos conhecidos

- **Consolidação não é atômica.** Uma falha no meio deixa um gasto duplicado (nunca perdido). Só um endpoint na API resolveria.
- **Sem atualização automática.** O que o outro usuário lança só aparece ao atualizar ou trocar de mês.
- **Edição simultânea.** Se os dois editarem o mesmo gasto, vale a última gravação; a API não tem controle de versão.
- **"1.234" sem vírgula** é lido como R$ 1,23 (ponto decimal), não como mil duzentos e trinta e quatro. O formato com vírgula não tem ambiguidade.
- **Fuso horário.** A data padrão de um gasto novo é o "hoje" do Mac; `createdAt` vem do servidor em UTC e só é usado para desempate na ordenação.
- **Textos da interface fixos em português**, direto no código, sem catálogo de localização.
- **Sem autenticação**, como o restante do sistema: quem tiver a URL da API lê e grava. Está previsto na Fase 3 da API.
- **`.pbxproj` editado à mão** em uma linha (`ENABLE_OUTGOING_NETWORK_CONNECTIONS`), no [Step 06](step-06-window-shell.md).

## Conexão com a próxima etapa

A Fase 1 termina aqui: o macOS faz tudo o que a web faz. A Fase 2 é o que justifica este cliente existir, as funcionalidades de análise. O primeiro candidato é um gráfico de evolução mensal (Swift Charts), em uma nova seção da sidebar, que a estrutura do [Step 06](step-06-window-shell.md) já prevê: um caso novo em `AppSection` e sua View.
