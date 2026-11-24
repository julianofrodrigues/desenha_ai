# 06 · Fase 5: categorias (Etapa 5A)

> **Nome do arquivo:** o pedido sugeria `docs/05-fase5-...`, mas o número 05
> já é o documento da Fase 4 (`docs/05-fase4-renomeacao-e-busca.md`). Para
> manter a ordem de leitura, este é o **06**.

A Fase 5 organiza o histórico por **categorias** escolhidas pelo usuário.
Ela foi dividida em etapas:

- **Etapa 5A** (seções 1 a 8): base de categorias, vínculo no Editar e
  badge.
- **Etapa 5B** (seção 9): faixa de categorias abaixo da busca, seletor com
  pesquisa e seleção múltipla, e filtro combinado com a busca.
- **Etapa 6D** (seção 10, parte do redesign da Fase 6): editar nome e cor
  de categorias existentes e paleta de 30 cores.

A Etapa 5A cobre:

- base de categorias offline (criar com nome + cor, remover);
- vínculo da categoria no botão **Editar** do desenho;
- **badge** com a cor e o nome da categoria no card.

Nada das Fases 1 a 4 foi descartado. O botão Editar continua renomeando
como na Fase 4, agora com a escolha de categoria no mesmo diálogo.

Arquivos da etapa:

```
lib/features/projects/
├─ models/
│  ├─ project_category.dart        ← ProjectCategory, paleta, validação do nome
│  └─ drawing_project.dart         ← ganhou categoryId, withCategory, categoryIn
├─ services/
│  ├─ category_repository.dart     ← contrato
│  ├─ file_category_repository.dart← categories.json
│  ├─ project_repository.dart      ← rename() virou updateDetails(); clearCategory()
│  └─ file_project_repository.dart
├─ screens/
│  └─ categories_screen.dart       ← criar e remover categorias
└─ widgets/
   ├─ category_badge.dart          ← badge (cor + nome) e bolinha de cor
   ├─ category_form_dialog.dart    ← nome + paleta
   ├─ edit_project_dialog.dart     ← antigo rename_project_dialog.dart
   └─ delete_project_dialog.dart   ← confirmação de excluir (saiu da Home)
```

---

## 1. Modelo e armazenamento

### 1.1 `ProjectCategory`

```dart
class ProjectCategory {
  final String id;        // a-z0-9, como os ids de projeto
  final String name;      // até 30 caracteres
  final int colorValue;   // ARGB, ex.: 0xFF43A047
}
```

A cor é um `int`, e não um `Color`, para o modelo não depender de UI. Ela
vira `Color(category.colorValue)` só na hora de desenhar.

### 1.2 Onde fica: `categories.json`

```
app_flutter/
  categories.json    ← todas as categorias (Fase 5)
  projects/
    lq3k9x2a7f/project.json   ← agora com "categoryId"
```

```json
{
  "schemaVersion": 1,
  "categories": [
    {"id": "lq3kb1c0d2", "name": "Animais", "color": 4282622023}
  ]
}
```

**Um arquivo só**, e não uma pasta por categoria como nos projetos:
categorias são poucas e pequenas, sem imagem. Ler e gravar a lista inteira é
instantâneo e mais simples. O arquivo fica **ao lado** da pasta `projects/`,
para não ser confundido com um projeto.

Valem as mesmas proteções da Fase 3 (docs/04):

- gravação **atômica** (arquivo `.tmp` + renomear);
- **fila** de escritas: criar duas categorias seguidas não faz uma apagar a
  outra;
- arquivo corrompido = nenhuma categoria (o app continua funcionando);
- arquivo de uma versão **mais nova** do app é recusado em vez de
  sobrescrito.

### 1.3 O projeto guarda só o id

O `project.json` ganhou o campo opcional `"categoryId"`. O projeto **não**
copia o nome nem a cor da categoria. Assim, excluir uma categoria só exige
limpar um id (e uma edição futura da categoria valeria para todos os
desenhos de uma vez).

Como na Fase 4, o campo é opcional: arquivos antigos continuam válidos, e o
`schemaVersion` não mudou.

---

## 2. Criar categorias

Na Home, o botão de **etiqueta** no topo abre a tela **Categorias**. "Nova
categoria" abre um formulário com nome e cor.

### 2.1 Validação amigável do nome

`validateCategoryName` é uma função pura, usada em dois lugares:

| Onde | Por quê |
| --- | --- |
| formulário | mostra o erro **embaixo do campo**, com o diálogo ainda aberto |
| repositório | última barreira: nunca grava um nome inválido |

| Digitado | Resultado |
| --- | --- |
| vazio ou só espaços | "Digite um nome para a categoria." |
| mais de 30 caracteres | "Use no máximo 30 caracteres." |
| "animais" já existindo "Animais" | "Já existe uma categoria com esse nome." |
| "Ânimais" já existindo "Animais" | duplicado (ignora acentos) |
| "  Retratos " | salvo como "Retratos" |

Duplicados são comparados com a **mesma normalização da busca**
(`normalizeForSearch`, Fase 4): para o usuário, "Animais" e "animais" são a
mesma etiqueta. O erro só aparece **depois** de tocar em Criar e some ao
voltar a digitar, para não "brigar" com quem ainda está escrevendo.

### 2.2 Paleta fixa

São 12 cores fixas (`categoryPalette`), cada uma com nome. Um seletor de cor
livre seria pesado, difícil de usar com o dedo e geraria cores parecidas
demais entre si.

- O formulário já começa numa cor **ainda não usada**.
- A cor escolhida ganha anel e "check". A seleção não depende só da cor
  (acessibilidade).
- Cada bolinha tem 40 dp de área de toque e uma dica com o nome
  ("Cor: Azul").

---

## 3. Remover categorias com segurança

```dart
// categories_screen.dart
await categoryRepository.delete(category);                 // 1º a categoria
final cleared = await projectRepository.clearCategory(id); // 2º os vínculos
```

- **Confirmação** antes, avisando que os desenhos **não** são apagados, só
  ficam sem categoria.
- `clearCategory` percorre os projetos e grava `categoryId: null` só nos que
  usavam aquela categoria. A mensagem diz quantos foram afetados.

### 3.1 Por que essa ordem, e por que é seguro

Se o app for fechado **entre** as duas etapas, alguns projetos ficam com um
`categoryId` que não existe mais. Isso não quebra nada, porque a UI nunca
confia cegamente no id:

```dart
// drawing_project.dart
T? categoryIn<T>(Map<String, T> categoriesById) {
  final id = categoryId;
  return id == null ? null : categoriesById[id]; // id desconhecido → null
}
```

- O card recebe a categoria **já resolvida**. Id desconhecido = sem badge.
- O diálogo Editar começa em "Sem categoria" se o id não existir mais.
- Na ordem inversa (limpar os projetos e depois apagar a categoria), uma
  falha no meio apagaria o trabalho do usuário sem ter removido a categoria.

---

## 4. Categoria no botão Editar

O diálogo da Fase 4 (`RenameProjectDialog`) virou `EditProjectDialog`
("Editar desenho"): mesmo campo de nome, mesmas regras, e embaixo a escolha
de categoria com **chips**: "Sem categoria" + uma por categoria, cada uma
com a sua cor.

**Por que chips, e não uma lista suspensa?** Com poucas categorias, todas
ficam visíveis de uma vez, com a cor ao lado, e escolher é um toque só.

O diálogo devolve um **registro** (record do Dart 3):

```dart
typedef ProjectEdit = ({String name, String? categoryId});
```

`null` = cancelou. A Home grava nome e categoria juntos, numa **única
gravação**:

```dart
_repository.updateDetails(project, customName: edit.name, categoryId: edit.categoryId);
```

- `updateDetails` substituiu o `rename` da Fase 4. Gravar os dois de uma vez
  evita um estado intermediário (nome novo com categoria antiga) se o app
  morrer entre duas gravações.
- Continua relendo o JSON do **disco** antes de gravar, para não perder os
  ajustes do salvamento automático (docs/05, 2.5).
- Não muda o "último acesso": o item não pula para o topo.
- Sem mudança real, não grava. A lista é atualizada **na hora**, trocando só
  o item editado.
- Mensagens: "Desenho renomeado." / "Nome original restaurado." (só o nome
  mudou, como na Fase 4), "Categoria atualizada." (só a categoria) e
  "Desenho atualizado." (os dois).

---

## 5. Badge no card

```
┌──────────────────────────────────────────────┐
│ [mini]  Gato laranja               ✏️   🗑️   │
│         05/03/2025 14:07 · Mesa de luz       │
│         (● Animais)                           │
└──────────────────────────────────────────────┘
```

- **Cor**: bolinha sólida + fundo bem clarinho (14%) + borda.
- **Nome**: na cor normal do texto do tema. Pintar o texto com a cor da
  categoria ficaria ilegível com cores claras (Âmbar, Lima) ou no tema
  escuro.
- Nome longo é cortado com "…", sem empurrar os botões.
- Para o leitor de tela, um único rótulo: "Categoria: Animais".
- **Sem categoria:** o card fica exatamente como na Fase 4, sem espaço vazio
  e sem mudar de altura.

### 5.1 Desempenho

A Home carrega projetos e categorias **em paralelo**:

```dart
final (projects, categories) = await (
  _loadOrEmpty(_repository.listRecent, 'histórico'),
  _loadOrEmpty(widget.categoryRepository.listAll, 'categorias'),
).wait; // `.wait` em um registro de Futures: dart:async
```

As categorias viram um **mapa por id**, montado uma vez por carregamento.
Cada card acha a sua categoria em tempo constante, sem percorrer a lista. A
badge é um widget sem estado, construído só quando o card aparece na lista
preguiçosa.

---

## 6. Organização (steering)

Para a `home_page.dart` não crescer além do recomendado:

- o diálogo de excluir desenho foi para `delete_project_dialog.dart` (mesmo
  texto e comportamento da Fase 3);
- a gestão de categorias ficou numa tela própria (`screens/`).

---

## 7. Testes

| Arquivo | O que cobre |
| --- | --- |
| `test/projects/categories_test.dart` | validação do nome (vazio, duplicado sem acento/maiúscula, longo), JSON, `categoryIn`, repositório real (criar, persistir, ordem, fila, remover, arquivo corrompido) e **limpeza do vínculo** nos projetos |
| `test/projects/categories_ui_test.dart` | badge (cor + nome; nada quando não há categoria válida), escolher/salvar/limpar/cancelar categoria no Editar, nome + categoria juntos, tela de categorias (criar com cor, erros, remover com confirmação, cancelar) |
| `test/widget_test.dart`, `file_project_repository_test.dart` | testes da Fase 4 atualizados para "Editar desenho" e `updateDetails` |

## 8. Como testar no aparelho

1. Na Home, toque na etiqueta do topo e crie "Animais" (verde) e "Retratos"
   (azul). Tente criar "animais" de novo: deve aparecer o aviso de duplicado.
2. Volte, toque no lápis de um desenho e escolha "Animais". A badge verde
   deve aparecer no card na hora.
3. Feche e reabra o app: a badge continua.
4. Em Categorias, remova "Animais". O desenho fica sem badge e continua
   abrindo normalmente.
5. Teste no tema escuro do aparelho: o nome na badge deve continuar legível.

---

## 9. Etapa 5B: faixa de categorias, seletor e filtro combinado

Arquivos da etapa:

```
lib/features/projects/
├─ models/
│  ├─ category_filter.dart         ← CategoryFilter (imutável, com ==)
│  └─ project_search.dart          ← ganhou applyHistoryFilters()
├─ screens/
│  └─ category_filter_screen.dart  ← pesquisar, marcar, criar e remover
└─ widgets/
   ├─ category_filter_bar.dart     ← faixa abaixo da busca
   ├─ category_actions.dart        ← remover categoria (compartilhado com a 5A)
   └─ category_form_dialog.dart    ← ganhou initialName
```

### 9.1 A faixa abaixo da busca

```
[🔍 Pesquisar desenhos                         ✕]
[ Sem categoria ] [● Animais ×] [● Retratos ×]   [🔎 Categorias (2)]
 └────────── rola para o lado ──────────┘        └── sempre visível
```

- **"Sem categoria"** está sempre lá, com **visual neutro**: contorno e
  texto nas cores de superfície do tema, ícone cinza, nunca uma cor de
  categoria nem a cor primária. Tocar marca/desmarca o filtro de desenhos
  sem categoria. Marcada, ganha fundo cinza claro e um "check": a seleção
  não depende só de cor.
- **Categorias marcadas** aparecem como etiquetas coloridas (mesmo estilo da
  badge do card) com "×" para tirá-las do filtro sem abrir o seletor.
- **O botão ao lado** ("Categorias", com o número de filtros ativos) abre o
  seletor para pesquisar, criar, remover e marcar.
- Fica numa **linha só**, com rolagem horizontal: muitas categorias
  marcadas não empurram a lista para baixo.

A faixa só aparece junto com a busca, ou seja, quando há desenhos no
histórico. O ícone de etiqueta da barra do topo (Etapa 5A) continua
existindo e abre a tela "Categorias".

### 9.2 Como o filtro decide o que aparece

| Marcado | Aparece |
| --- | --- |
| nada | **todos** os desenhos (igual às Fases 3 e 4) |
| uma ou mais categorias | só os desenhos dessas categorias |
| "Sem categoria" | só os desenhos sem categoria, **incluindo** os que apontam para uma categoria apagada |
| categorias + "Sem categoria" | a **união** dos dois conjuntos |

> **Interpretação do pedido:** sem nada marcado, mostramos **todos** os
> desenhos, e não só os sem categoria. Esconder os desenhos com categoria
> por padrão quebraria o comportamento das Fases 3 e 4, e o usuário
> "perderia" desenhos ao criar a primeira categoria.

### 9.3 Filtro combinado com a busca do topo

```dart
// project_search.dart
List<DrawingProject> applyHistoryFilters(projects, {query, categoryFilter, categoriesById}) {
  final inCategories = categoryFilter.isActive
      ? [for (final p in projects) if (categoryFilter.matches(p, categoriesById)) p]
      : projects;
  return filterProjects(inCategories, query); // busca da Fase 4
}
```

1. **Primeiro as categorias**, depois a busca por nome. Com "Animais"
   marcada, digitar "gato" procura **só** entre os desenhos de Animais.
2. A busca é a mesma `filterProjects` da Fase 4, então a **prioridade de
   nomes continua**: nome editado > nome original do arquivo > "Imagem".
3. Com "Sem categoria" marcada, a busca funciona normalmente sobre esse
   conjunto.
4. Sem filtro, o resultado é **idêntico** ao da Fase 4.

Mensagens quando nada aparece:

| Situação | Mensagem |
| --- | --- |
| filtro ativo, busca vazia | "Nenhum desenho nas categorias selecionadas." |
| filtro ativo + busca | "Nenhum desenho encontrado para “x” nas categorias selecionadas." |
| só busca (Fase 4) | "Nenhum desenho encontrado para “x”." |

### 9.4 O seletor (`CategoryFilterScreen`)

Abre pelo botão da faixa como uma **tela cheia** (`fullscreenDialog`: sobe
de baixo e tem "X" no lugar da seta).

**Por que uma tela, e não um painel inferior (`BottomSheet`)?** Com o
teclado aberto num celular, o painel fica espremido. E as mensagens de
"categoria criada/removida" (SnackBar) ficariam escondidas atrás dele. A
tela tem o seu próprio `Scaffold`.

| Ação | Como |
| --- | --- |
| pesquisar | campo no topo; filtra em tempo real, sem acento/maiúscula; "sem" também encontra "Sem categoria" |
| marcar várias | caixa de seleção em cada linha (a linha inteira é tocável) |
| criar | botão **+** no topo, ou a linha **"Criar categoria “x”"** quando a pesquisa não encontra um nome igual (o formulário abre com o nome preenchido) |
| remover | lixeira em cada linha, com a mesma confirmação da 5A; os desenhos ficam sem categoria |
| aplicar | botão de baixo: "Aplicar (N selecionadas)" ou "Mostrar todos os desenhos" |
| limpar | "Limpar" no topo desmarca tudo (ainda precisa aplicar) |
| desistir | "X": as **marcações** são descartadas |

**Marcações são um rascunho.** Elas só valem para o histórico ao tocar em
Aplicar. Já criar e remover categorias são gravados **na hora**, então
fechar no "X" não desfaz isso. Por isso a Home **sempre** recarrega o
histórico quando o seletor fecha.

### 9.5 Estado e ciclo de vida

| Objeto | Dono | Descartado em |
| --- | --- | --- |
| `ValueNotifier<CategoryFilter>` (filtro ativo) | `_HomePageState` | `dispose` da Home |
| `TextEditingController` + `FocusNode` (pesquisa de categorias) | `_CategoryFilterScreenState` | `dispose` do seletor |
| `TextEditingController` (nome da categoria nova) | `_CategoryFormDialogState` | `dispose` do formulário |

- O filtro é um **`ValueNotifier`** (steering, seção 3). Marcar ou desmarcar
  reconstrói só a faixa e a lista, não a Home inteira.
- `CategoryFilter` é **imutável com `==`**: o notifier só avisa quando o
  filtro muda de verdade. A comparação dos ids não depende da ordem em que
  foram marcados.
- A lista escuta **busca e filtro** juntos com
  `ListenableBuilder(listenable: Listenable.merge([...]))`.
- No seletor, só a **lista de opções** escuta o texto da pesquisa.

### 9.6 Categoria removida que estava no filtro

Sempre que a Home recarrega, o filtro passa por
`retainOnly(categoriasExistentes)`. Uma categoria removida (no seletor ou
na tela "Categorias") sai do filtro na hora. Sem isso, um filtro só com
categorias apagadas esconderia todos os desenhos sem o usuário entender por
quê. Se o histórico ficar vazio, o filtro é zerado, como a busca da Fase 4.

### 9.7 Compartilhado com a Etapa 5A

A confirmação e a remoção de categoria (primeiro a categoria, depois os
vínculos) foram para `category_actions.dart`. A tela "Categorias" e o
seletor usam o mesmo código, com o mesmo texto e a mesma ordem segura.

### 9.8 Testes

| Arquivo | O que cobre |
| --- | --- |
| `test/projects/category_filter_test.dart` | `CategoryFilter` (marcar, `==` sem ordem, `retainOnly`) e `applyHistoryFilters`: sem filtro, uma categoria, várias (união), busca restrita às marcadas, prioridade de nomes dentro do filtro, "Sem categoria" (com categoria apagada) e combinações |
| `test/projects/category_filter_ui_test.dart` | faixa (etiqueta neutra abaixo da busca, botão ao lado, sem bolinha de cor), "Sem categoria" pela faixa, "×" nas etiquetas, seletor (pesquisa, seleção múltipla, "X" descarta, Limpar, criar pela pesquisa com nome preenchido, sem "Criar" para nome existente, remover com confirmação limpando vínculos e filtro, `dispose`), filtro combinado com a busca do topo, mensagens, mudar a categoria pelo Editar |

### 9.9 Como testar no aparelho

1. Com desenhos de categorias diferentes, toque em **Categorias** na faixa,
   marque duas e aplique: só os desenhos delas aparecem, e a faixa mostra
   as duas etiquetas.
2. Digite na busca do topo: ela procura só dentro dessas categorias.
3. Toque no "×" de uma etiqueta: o filtro diminui na hora.
4. Toque em "Sem categoria" na faixa: só os desenhos sem categoria.
5. No seletor, pesquise um nome que não existe e use **"Criar categoria
   “…”"**. Remova uma categoria marcada: ela sai do filtro e os desenhos
   ficam sem badge.
6. No celular deitado, abra o seletor com o teclado aberto: a lista deve
   rolar sem cortar o botão "Aplicar".

---

## 10. Etapa 6D: editar categorias e paleta de 30 cores

> A Etapa 6D faz parte da Fase 6 (docs/07), mas é documentada aqui porque
> muda as **categorias**.

### 10.1 Botão Editar nas categorias

Cada categoria ganhou um **lápis** ("Editar categoria") à **esquerda** da
lixeira, nas duas telas que gerenciam categorias:

| Tela | Quando aparece |
| --- | --- |
| **Categorias** (`CategoriesScreen`) | botão "Categorias" da tela inicial (sem desenhos) |
| **Filtrar por categoria** (`CategoryFilterScreen`) | botão "Categorias" da faixa abaixo da busca (com desenhos) |

As duas usam a **mesma** função, `editCategory` (`category_actions.dart`),
com o mesmo formulário, as mesmas mensagens e a mesma validação.

### 10.2 O formulário de edição

É o **mesmo** `CategoryFormDialog` da criação, em modo edição (`editing:`):

| | Criar | Editar |
| --- | --- | --- |
| título | "Nova categoria" | "Editar categoria" |
| botão | "Criar" | "Salvar" |
| nome inicial | vazio (ou o texto da pesquisa, 5B) | o nome atual |
| cor inicial | a primeira cor ainda não usada | a cor atual |
| teclado abre sozinho | sim | não (muitas vezes só se troca a cor, e o teclado cobriria a paleta) |

Validação do nome ao editar (`validateCategoryName(..., exceptId:)`):

| Digitado | Resultado |
| --- | --- |
| vazio ou só espaços | "Digite um nome para a categoria." |
| nome de **outra** categoria (sem maiúsculas/acentos) | "Já existe uma categoria com esse nome." |
| o **próprio** nome, ou só mudando maiúsculas ("animais" → "Animais") | permitido |
| mesmo nome e mesma cor | não grava nada |
| Cancelar | nada muda |

### 10.3 Gravação e reflexo nos cards

```dart
// file_category_repository.dart
Future<ProjectCategory> update(ProjectCategory category, {name, colorValue})
```

- Relê o `categories.json` do **disco** dentro da fila de escritas, valida
  de novo (a última barreira) e grava de forma **atômica**, como as outras
  operações.
- O **`id` nunca muda**. Isso é o que faz a edição ser barata e segura:

> Os desenhos guardam só o `categoryId` (seção 1.3). Editar a categoria
> grava **um** arquivo (`categories.json`) e **nenhum** projeto. Quando a
> Home recarrega (ela sempre recarrega ao fechar as telas de categoria), o
> mapa `categoriesById` já traz o nome e a cor novos, e **todos** os cards
> vinculados mostram a badge atualizada.

Outros efeitos, todos de graça pelo mesmo motivo:

- a categoria **continua marcada** no filtro (o filtro guarda ids);
- a etiqueta da faixa (5B) aparece com o nome e a cor novos;
- os chips do diálogo "Editar desenho" (5A) também.

Erros previstos:

| Situação | Mensagem |
| --- | --- |
| a lista mudou e o nome virou duplicado | a mesma do formulário |
| a categoria foi removida (`CategoryNotFoundException`) | "Esta categoria não existe mais." |
| falha de disco | "Não foi possível salvar a categoria." |

### 10.4 Paleta de 30 cores

As **12 primeiras** são as da Etapa 5A, na **mesma ordem e valor**:
categorias já criadas não mudam de cor. As **18 novas** vêm em grupos:

| Família | Cores |
| --- | --- |
| 5A (originais) | Vermelho, Rosa, Roxo, Anil, Azul, Ciano, Verde-azulado, Verde, Lima, Âmbar, Laranja, Marrom |
| vermelhos, rosas e laranjas | Vinho, Rosa-claro, Salmão, Pêssego, Terracota |
| roxos | Magenta, Lavanda, Violeta |
| azuis | Azul-cobalto, Azul-céu, Azul-aço |
| verdes | Menta, Verde-escuro, Verde-maçã, Oliva |
| amarelos e neutros | Dourado, Areia, Grafite |

**Garantias, por teste** (`test/projects/category_palette_test.dart`):

- exatamente **30** cores, todas diferentes, com nomes únicos e opacas;
- **contraste > 1,5** contra o card do tema **claro** e do **escuro**: são
  tons médios, nada perto do branco nem do preto, então a bolinha da badge
  nunca some (o **texto** da badge usa a cor do tema, seção 5);
- **bem distribuídas**: nenhum par de cores fica a menos de 35 de distância
  no espaço RGB (o teste mostra o par mais próximo se falhar).

**Leveza na tela:**

- grade com **largura fixa**: 5 colunas no celular e 6 no tablet. Uma `Wrap`
  solta faria o `AlertDialog`, que mede a largura "natural" do conteúdo,
  somar as 30 bolinhas numa linha e esticar até a borda da tela no tablet;
- 30 bolinhas simples (`InkWell` + círculo), sem rolagem própria e sem
  pacote de seletor de cor; o diálogo inteiro rola se faltar altura;
- o "check" da cor escolhida fica **escuro nas cores claras** (Pêssego,
  Azul-céu...) e branco nas escuras.

### 10.5 Testes

| Arquivo | O que cobre |
| --- | --- |
| `test/projects/category_palette_test.dart` | 30 cores únicas e opacas, as 12 da 5A preservadas, contraste nos dois modos, distância mínima; `validateCategoryName` com `exceptId`; `FileCategoryRepository.update` (grava e relê com "app novo", só cor, só maiúsculas, recusa vazio/duplicado sem gravar, categoria removida) |
| `test/projects/category_edit_ui_test.dart` | lápis à esquerda da lixeira; formulário com nome e cor atuais; salvar muda lista e armazenamento; duplicado recusado com diálogo aberto; só a cor; cancelar/sem mudança não grava; as 30 cores ao criar e editar; grade compacta no tablet e 5 colunas em 360 dp; editar pelo seletor atualiza a badge dos cards (nome + cor), mantém o filtro e não regrava nenhum projeto; editar pela tela "Categorias" |

### 10.6 Como testar no aparelho

1. Com desenhos de uma categoria, abra **Categorias** na faixa e toque no
   lápis dela. Troque o nome e a cor e salve.
2. Aplique (ou feche no "X"): os cards daquela categoria mostram o nome e a
   cor novos.
3. Tente renomear para o nome de outra categoria: aparece o aviso, e nada
   muda.
4. Feche e reabra o app: a edição continua lá.
5. Abra "Nova categoria" no Galaxy Tab A e no RedMagic: as 30 cores ficam
   numa grade compacta, sem esticar o diálogo.
6. No tema escuro, confira se Vinho e Grafite continuam visíveis na badge.
