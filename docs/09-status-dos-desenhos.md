# 09 · Etapa final: gerenciador manual de status dos desenhos

**Entrega:** cada desenho tem um status escolhido pelo usuário, mostrado
como etiqueta no card, trocado por um botão do card e usado como filtro
direto na listagem, junto com a busca e as categorias.

Tudo continua 100% offline: o status fica no `project.json` de cada
projeto, no armazenamento privado do app.

---

## 1. Os 4 status

| Status | Ícone | Claro | Escuro | Ideia |
| --- | --- | --- | --- | --- |
| **Não iniciado** | `radio_button_unchecked` (círculo vazio) | ardósia `#526075` | ardósia clara `#A9B4C6` | neutro, ainda parado |
| **Em andamento** | `brush_outlined` (pincel) | âmbar escuro `#B45309` | âmbar `#FBBF4C` | na mesa, atenção |
| **Concluído** | `check_circle_outline` (check) | verde `#15803D` | verde claro `#4ADE80` | pronto |
| **Arquivado** | `inventory_2_outlined` (caixa de arquivo) | cinza-arroxeado `#6A6288` | lilás-acinzentado `#B7AFCF` | guardado, fora do caminho |

- **Um tom por modo.** No claro os tons são escuros (contraste ≥ 5:1 sobre o
  card branco); no escuro, claros (≥ 8:1 sobre o card grafite). Um único tom
  não serve para os dois: o âmbar que se lê bem no escuro some no branco.
  Um teste confere o mínimo de 4,5:1 nos dois modos.
- **A cor nunca é a única pista.** Cada status tem ícone próprio e o nome
  escrito. O texto das etiquetas usa a cor normal do tema; a cor do status
  vai no ícone, na borda e num fundo de 14%.
- **Arquivado** puxa para o violeta da marca, para não se confundir com a
  ardósia do "Não iniciado".

As cores ficam em `AppPalette` (como todas as cores do app). O ícone e a
escolha do tom pelo modo ficam na extensão `ProjectStatusStyle`
(`widgets/project_status_style.dart`), para o modelo continuar sem Flutter
UI.

---

## 2. Controle 100% manual

O status só muda pelo botão de status do card. O app nunca o altera
sozinho:

| Ação | Status |
| --- | --- |
| Adicionar imagens (uma ou várias) | sempre **Não iniciado** |
| Abrir, desenhar, fechar a tela de desenho | não muda |
| Salvamento automático dos ajustes | não muda (`copyWith` mantém o status) |
| Renomear ou trocar a categoria | não muda |
| Botão de status do card | muda para o escolhido |

Por quê: só o usuário sabe se terminou um desenho ou quer guardá-lo. Um
palpite automático ("abriu, então está em andamento") erraria e teria de ser
corrigido à mão.

`ProjectRepository.updateStatus` é a única operação que grava um status
novo. Como o `updateDetails` da Fase 4, ela:
- parte do que está no DISCO (não perde ajustes gravados depois de a lista
  ser lida);
- não altera o "último acesso", então o card não pula para o topo;
- não grava nada se o status não mudou.

---

## 3. Persistência retrocompatível

```json
{
  "schemaVersion": 1,
  "id": "lq3k9x2a7f",
  "status": "inProgress",
  ...
}
```

- O valor gravado é um texto fixo (`notStarted`, `inProgress`, `done`,
  `archived`), separado do nome do enum no código. Renomear uma constante no
  futuro não quebra os arquivos salvos.
- **Campo opcional:** um `project.json` salvo antes desta etapa não tem
  `status` e é lido como **Não iniciado**. Um valor desconhecido (arquivo
  editado à mão) também. Por isso o `schemaVersion` continua 1, como já tinha
  acontecido com `customName` (Fase 4) e `categoryId` (Fase 5).

---

## 4. No card

```
[miniatura]  gato.png                         [⚑] [✎] [🗑]
             05/03/2025 14:07 · Câmera
             (○ Não iniciado) (● Animais)
```

- **Botão de status** (`Icons.flag_outlined`, "Alterar status") à esquerda
  do Editar, que continua à esquerda do Excluir. Da esquerda para a direita,
  as ações vão da mais leve à destrutiva.
- **Badge de status** (ícone + cor + nome) à esquerda da badge de categoria,
  no mesmo molde dela. Ela aparece em TODO card, com ou sem categoria. As duas
  ficam num `Wrap`: num celular estreito, a categoria desce para a linha de
  baixo em vez de dar overflow, e o nome do status ganha "…" se faltar
  espaço.

### Diálogo de status

Um `SimpleDialog` "Status do desenho" com os 4 status (ícone em círculo
colorido, nome e "check" no atual). **Um toque já escolhe e salva**, sem
botão "Salvar": são só quatro opções e trocar de novo é igualmente rápido.
"Cancelar", tocar fora ou o botão voltar do Android fecham sem mudar nada.

Depois de salvar, a Home troca só o item na lista e mostra
`Status alterado para "Concluído".`. Se o status novo não está marcado no
filtro, o card sai da lista na hora, e a mensagem acrescenta: "O desenho saiu
da lista porque esse status não está marcado no filtro."

---

## 5. Filtro de status

```
[ Pesquisar desenhos…                                       ]
Status dos desenhos
(∞ Todos) (○ Não iniciado) (🖌 Em andamento) (✓ Concluído) (▣ Arquivado)
Categorias
[Sem categoria] [● Animais ×] ...                 [Categorias (1)]
```

- Fica **entre a barra de pesquisa e a faixa de categorias**.
- **Títulos:** "Status dos desenhos" fica entre a pesquisa e os chips de
  status, e "Categorias" entre os chips de status e a faixa de categorias.
  Eles deixam claro qual linha filtra o quê. Usam `labelLarge` (seminegrito)
  na cor secundária do tema (`onSurfaceVariant`), que se ajusta ao claro e
  ao escuro e não compete com o título "Continuar desenhando" nem com os
  chips. Ficam alinhados à esquerda com os chips (16 dp).
- **Espaçamento:** cada título fica a 6 dp do SEU filtro e a 12 dp do bloco
  de cima, para a leitura agrupar "título + chips" sem abrir buracos.
- Os títulos são `const` e não escutam nenhum filtro: marcar um chip nunca
  os reconstrói. Para o leitor de tela, são cabeçalhos
  (`Semantics(header: true)`).
- **"Todos"** (`Icons.all_inclusive`) vem primeiro, imediatamente à esquerda
  de "Não iniciado". Depois vêm os 4 status, **direto na tela**, como
  `FilterChip`s com ícone e nome, num `Wrap`: num celular em pé ocupam duas
  linhas, mas nenhum fica escondido. Sem diálogo e sem busca.
- Marcado = fundo na cor do chip, borda de 2 dp e texto em negrito (três
  sinais, não só a cor). "Todos" usa a cor principal do tema, que já tem um
  tom para o claro (violeta) e outro para o escuro (violeta claro).
- "Todos" e os status usam o mesmo widget de visual (`_ChipLook`), para o
  molde nunca divergir.

### 5.1 "Todos" e as transições automáticas

"Todos" não é um quinto valor guardado à parte: ele aparece marcado
**quando nenhum status específico está marcado**
(`StatusFilter.showsAll`). Assim nunca existe a combinação "todos os chips
apagados", e as regras saem sozinhas, sem estado extra para manter em
sincronia:

| Ação | Resultado |
| --- | --- |
| Abrir o app | **Todos** marcado, os 4 específicos desmarcados, todos os desenhos à vista (`StatusFilter.initial`, que é o filtro vazio). |
| Tocar em **Todos** | **Todos** marcado, os 4 específicos desmarcados, mostra desenhos de qualquer status. |
| Tocar em **Todos** já marcado | nada muda (o filtro é igual e o notifier nem avisa). |
| Marcar um status específico | **Todos** desmarca sozinho; ficam só os específicos marcados. |
| Desmarcar um específico, com outros ainda marcados | **Todos** continua desmarcado. |
| Desmarcar o **último** específico | **Todos** marca sozinho e a lista mostra todos. |

Com "Todos" marcado, a busca e o filtro de categorias continuam valendo: a
lista mostra os desenhos de qualquer status que passem nos dois.

### Filtro combinado

Um desenho só aparece se passar nos três ao mesmo tempo:

1. **status** marcado (ou nenhum marcado);
2. **categoria** marcada (ou nenhuma marcada);
3. **texto** da busca no nome exibido.

`applyHistoryFilters` aplica status e categoria numa passada só e depois a
busca, dentro do que sobrou. Mensagens de lista vazia:

| Situação | Mensagem |
| --- | --- |
| Sem texto, os filtros esconderam tudo | "Nenhum desenho com os filtros selecionados." |
| O texto existe em algum desenho, mas fora dos filtros | "Nenhum desenho encontrado para “x” com os filtros selecionados." |
| Nenhum desenho tem esse nome | "Nenhum desenho encontrado para “x”." |

### Interação com outras partes

- **Adicionar imagens:** elas entram como "Não iniciado". Se esse status
  estava desmarcado, ele é marcado de volta, sem desmarcar os outros, para as
  imagens novas aparecerem (`StatusFilter.including`).
- **Histórico vazio** (excluiu o último): o filtro volta ao padrão.
- O filtro vive na Home (`ValueNotifier`, descartado no `dispose`) e
  sobrevive às trocas de estado ("Abrindo desenho…"), como a busca e as
  categorias.

### Desempenho

Só a faixa de status e a lista escutam o filtro: marcar um chip não
reconstrói o botão "Novo desenho", a busca nem a faixa de categorias. O
filtro é imutável, com `==`, e o notifier só avisa quando algo mudou de fato.
Filtrar dezenas de projetos leva microssegundos, mesmo no Galaxy Tab A.

---

## 6. Código

| Arquivo | Papel |
| --- | --- |
| `projects/models/project_status.dart` | Enum `ProjectStatus` (4 status, nome, valor do JSON, leitura tolerante). |
| `projects/models/status_filter.dart` | `StatusFilter` imutável: `initial`, `none`, `toggle`, `including`, `matches`. |
| `projects/models/drawing_project.dart` | Campo `status`, `withStatus`, JSON retrocompatível. |
| `projects/models/project_search.dart` | `applyHistoryFilters` com `statusFilter`. |
| `projects/services/project_repository.dart` + `file_project_repository.dart` | `updateStatus`. |
| `projects/widgets/project_status_style.dart` | Ícone e cor (claro/escuro) de cada status. |
| `projects/widgets/project_status_badge.dart` | Badge do card. |
| `projects/widgets/project_status_dialog.dart` | Diálogo e mensagem de confirmação. |
| `projects/widgets/status_filter_bar.dart` | Faixa de filtro com os 4 chips. |
| `projects/widgets/project_history_tile.dart` / `project_history_list.dart` | Botão e badge no card; faixa e filtro combinado na lista. |
| `image_selection/presentation/home_page.dart` | `_statusFilter`, `_changeStatus`. |
| `theme/app_palette.dart` | As 8 cores de status. |

### Conceitos de Dart/Flutter praticados

- **Enum com campos** (`jsonValue`, `label`) e construtor `const`.
- **Extension** para dar ícone e cor ao enum sem pôr Flutter no modelo.
- **Registros e padrões** (`(Brightness, Color)`) nos testes de contraste.
- **`Object.hashAllUnordered`** para um `hashCode` que independe da ordem.

---

## 7. Testes

- `test/projects/project_status_test.dart` (unidade):
  - os 4 status e os nomes; leitura tolerante do JSON;
  - projeto novo em "Não iniciado"; ida e volta pelo JSON; **JSON antigo sem
    o campo vira "Não iniciado"**; `schemaVersion` continua 1;
  - `withStatus` não mexe no último acesso; renomear, trocar categoria e
    salvar ajustes mantêm o status;
  - `StatusFilter`: padrão, marcar vários, nenhum = todos, `showsAll` (o
    estado do chip "Todos" em cada transição), `including`,
    `==`/`hashCode`;
  - filtro combinado de status + categoria + busca;
  - repositório real: imagem nova grava `notStarted`, `project.json` antigo
    é lido como "Não iniciado", `updateStatus` não muda o último acesso,
    `save` e `updateDetails` mantêm o status, projeto excluído falha;
  - ícones distintos; cores distintas, com contraste ≥ 4,5:1, e diferentes
    entre claro e escuro.
- `test/projects/project_status_ui_test.dart` (widget):
  - botão de status à esquerda do Editar (que fica à esquerda do Excluir);
  - diálogo com os 4 status e o atual marcado; escolher salva na hora,
    atualiza a badge e não muda a ordem; status fora do filtro tira o card
    e explica; cancelar ou escolher o mesmo não grava;
  - badge à esquerda da categoria; sem categoria, só a de status; tom do modo
    escuro; 360 dp sem overflow;
  - faixa entre a busca e as categorias; 4 chips com ícone e nome, sem
    diálogo; os 4 específicos desmarcados ao abrir; vários marcados;
    nenhum = todos; combinação com busca e com categorias + busca; mensagens
    de lista vazia;
  - **títulos**: "Status dos desenhos" entre a pesquisa e os chips de status,
    "Categorias" entre os chips de status e a faixa de categorias, os dois
    alinhados com o filtro, a até 8 dp dele e marcados como cabeçalho para o
    leitor de tela; modo escuro e 360 dp sem overflow;
  - **chip "Todos"**: imediatamente à esquerda de "Não iniciado", com ícone,
    nome e a mesma altura dos status; **marcado ao abrir**, com todos os
    desenhos à vista; tocar nele limpa
    os específicos e mostra todos; tocar de novo não muda nada; marcar um
    específico o desmarca; desmarcar o último específico o marca; com dois
    marcados, tirar um não o marca; combina com categoria e busca; 360 dp
    sem overflow;
  - **abrir e fechar o desenho não muda o status**; imagem nova entra como
    "Não iniciado" e aparece mesmo com outro status filtrado.
- `test/fakes.dart`: `sampleProject(status: ...)` e
  `FakeProjectRepository.updateStatus` com `statusChanges`.
- `test/projects/category_filter_ui_test.dart`: as duas mensagens de lista
  vazia passaram a falar em "filtros selecionados".

---

## 8. Como testar no aparelho

1. Abra o app: os títulos "Status dos desenhos" e "Categorias" aparecem
   acima das suas linhas de filtro; "Todos" está marcado e todos os
   desenhos estão à vista. Os antigos aparecem com "Não iniciado".
2. Num card, toque na bandeira (à esquerda do lápis) e escolha "Em
   andamento": o card continua na lista (com "Todos"), agora com a etiqueta
   âmbar à esquerda da categoria. Marque só "Não iniciado" no filtro: o card
   some; troque outro card de status e a mensagem explica por que ele saiu.
3. Abra esse desenho e volte: o status continua "Em andamento".
4. Combine: marque um status, uma categoria e pesquise um nome. Só aparece
   o que atende aos três.
5. Alterne claro/escuro: as cores de etiquetas e chips mudam de tom e
   continuam legíveis.
6. Adicione imagens com "Novo desenho": elas entram como "Não iniciado".
