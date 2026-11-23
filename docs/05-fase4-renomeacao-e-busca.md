# 05 · Fase 4: renomear desenhos e pesquisar no histórico

A Fase 4 melhora a seção "Continuar desenhando" da Fase 3 **sem descartar
nada**: os arquivos, o salvamento automático e a exclusão continuam iguais.

Arquivos da fase:

```
lib/features/projects/
├─ models/
│  ├─ drawing_project.dart        ← ganhou customName, displayName e rename()
│  └─ project_search.dart         ← filterProjects() e normalizeForSearch()
├─ services/
│  ├─ project_repository.dart     ← ganhou rename()
│  └─ file_project_repository.dart← implementação do rename()
└─ widgets/
   ├─ project_history_list.dart   ← lista + barra de pesquisa (saiu da Home)
   ├─ project_history_tile.dart   ← ganhou o botão Editar
   ├─ project_search_field.dart   ← campo de busca com botão de limpar
   └─ rename_project_dialog.dart  ← diálogo de renomear

lib/features/image_selection/presentation/
├─ home_page.dart                 ← dona do controller/foco da busca; _rename()
└─ widgets/home_status_views.dart ← boas-vindas/carregando/erro (saíram da Home)
```

> **Registro:** a Fase 3 está concluída. O recurso de salvar "até onde o
> traçado foi feito" foi **cancelado** e não será implementado (ver
> `docs/02-roadmap-desenha-ai.md`).

---

## 1. Prioridade de nomes

Cada projeto pode ter até dois nomes:

| Campo | De onde vem | Pode mudar? |
| --- | --- | --- |
| `originalName` | nome do arquivo escolhido na galeria (ex.: `IMG_2025.jpg`) | **nunca** |
| `customName` | digitado pelo usuário no app (Fase 4) | sim; `null` = sem nome customizado |

O nome **exibido e pesquisado** segue esta ordem:

```dart
// lib/features/projects/models/drawing_project.dart
String get displayName {
  final custom = customName?.trim();
  if (custom != null && custom.isNotEmpty) return custom; // 1º customizado
  final original = originalName.trim();
  if (original.isNotEmpty) return original;               // 2º original
  return fallbackName;                                     // 3º "Imagem"
}
```

- O 3º nível, `"Imagem"`, é o mesmo texto que a Fase 3 já usava quando um
  `project.json` não tinha `originalName`. Agora ele fica numa constante
  (`DrawingProject.fallbackName`), e o `originalName` vazio continua vazio,
  sem ser trocado por "Imagem" na leitura. Assim "sem nome" não se confunde
  com "arquivo chamado Imagem".
- A regra fica **no modelo**, e não num widget, para que lista, busca e
  diálogo de exclusão nunca discordem sobre qual é o nome.

---

## 2. Renomear só dentro do app

### 2.1 O que muda e o que não muda

Renomear grava **só** o campo `customName` no `project.json`:

```json
{
  "schemaVersion": 1,
  "id": "lq3k9x2a7f",
  "originalName": "IMG_2025.jpg",
  "customName": "Gato azul",
  "imageFile": "image.jpg",
  ...
}
```

Não muda:

- o arquivo na galeria (o app nem tem acesso a ele depois de copiá-lo);
- a cópia `image.jpg` e a miniatura `thumb.png` da pasta do projeto;
- os ajustes de desenho e o `updatedAt`. Renomear não é "continuar
  desenhando", então o item **não pula para o topo** da lista.

### 2.2 Por que o `schemaVersion` continuou 1

`customName` é um campo **opcional**. Um `project.json` da Fase 3 (sem o
campo) é lido normalmente, com `customName = null`. Só aumentaríamos a versão
se um arquivo novo **não pudesse** ser lido corretamente pela regra antiga,
o que não é o caso.

### 2.3 Regras do nome digitado

`DrawingProject.normalizeCustomName` decide o que é salvo:

| Digitado | Salvo como `customName` | Exibido |
| --- | --- | --- |
| `"  Gato azul  "` | `"Gato azul"` | Gato azul |
| `""` ou `"    "` | `null` | nome original |
| igual ao `originalName` | `null` | nome original |
| mais de 80 caracteres | cortado em 80 | os 80 primeiros |
| (Cancelar) | nada muda | nome anterior |

"Deixar em branco" é o jeito de **desfazer** a renomeação, e o diálogo avisa
isso no texto de ajuda ("Deixe em branco para voltar ao nome original:
IMG_2025.jpg"). Salvar sem mudar nada não grava nem mostra mensagem.

### 2.4 O diálogo devolve um valor

```dart
// rename_project_dialog.dart
Future<String?> showRenameProjectDialog(BuildContext context, DrawingProject p) =>
    showDialog<String>(context: context, builder: (_) => RenameProjectDialog(project: p));

// Dentro do diálogo:
Navigator.of(context).pop(_controller.text); // Salvar
Navigator.of(context).pop();                 // Cancelar → null
```

`showDialog<T>` devolve um `Future<T?>` que completa quando o diálogo fecha.
`null` significa "cancelou"; qualquer texto (até vazio) significa "salvar
isto". A Home só decide o que fazer com o resultado.

O diálogo é um `StatefulWidget` porque é **dono** do seu
`TextEditingController`: cria no início e descarta no `dispose`. O campo
começa com o nome exibido todo selecionado: dá para digitar por cima ou só
corrigir uma letra.

### 2.5 Por que o repositório relê o disco

```dart
// file_project_repository.dart
final current = DrawingProject.fromJson(jsonDecode(await file.readAsString()));
final renamed = current.rename(customName);
```

A lista da Home pode estar um pouco **desatualizada**: ao voltar da tela de
desenho, o salvamento automático (`flush` no `dispose`) pode terminar depois
de a lista ser lida. Se o `rename` gravasse o objeto da lista, os ajustes mais
novos seriam perdidos. Relendo o disco dentro da fila de escritas
(`_serialized`), só o nome muda. O teste "não perde ajustes salvos depois de a
lista ser lida" cobre esse caso.

### 2.6 Lista atualizada na hora

Depois de salvar, a Home troca **só o item renomeado** na lista que já está
na memória, sem reler o disco. A ordem não muda, porque o `updatedAt` não
mudou.

---

## 3. Barra de pesquisa

### 3.1 `TextEditingController` e `FocusNode`

| Objeto | Para que serve | Quem cria e descarta |
| --- | --- | --- |
| `TextEditingController` | guarda o texto digitado e a seleção | `_HomePageState` |
| `FocusNode` | controla se o campo tem o foco (teclado aberto) | `_HomePageState` |

Os dois ficam na **Home**, e não no widget da lista, porque a lista some e
volta quando a Home troca de estado (por exemplo, "Abrindo desenho…"). Na
Home, o texto pesquisado sobrevive a isso. Os dois são liberados no
`dispose` da Home: os dois seguram ouvintes, e o `FocusNode` também fica
registrado na árvore de foco do app.

O `FocusNode` é usado para:

- fechar o teclado ao tocar fora do campo (`onTapOutside`) e ao rolar a lista
  (`keyboardDismissBehavior: onDrag`), porque no celular o teclado cobre
  metade da lista;
- devolver o foco ao campo depois de tocar em limpar;
- fechar o teclado antes de abrir os diálogos de renomear e excluir.

### 3.2 Sem `setState` a cada tecla

O `TextEditingController` **é** um `ValueNotifier<TextEditingValue>`. Por
isso ele alimenta `ValueListenableBuilder`s diretamente (o mesmo padrão da
Fase 2, docs/03):

```dart
// project_history_list.dart
ValueListenableBuilder<TextEditingValue>(
  valueListenable: searchController,
  builder: (context, value, _) {
    final visible = filterProjects(projects, value.text);
    ...
  },
);
```

A cada tecla, só são reconstruídos o campo (para mostrar ou esconder o botão
de limpar) e a lista filtrada. O botão "Novo desenho", o título e a Home não
são reconstruídos.

### 3.3 Por que não usar debounce na busca

Na Fase 3 usamos debounce para **gravar em disco**, que é lento. Aqui é
diferente: filtrar uma lista de dezenas de nomes na memória leva
microssegundos, mesmo no Galaxy Tab A. Esperar 300 ms faria a busca
**parecer** lenta sem economizar nada. A lista também continua preguiçosa
(`SliverList.builder`), então só os itens visíveis montam a miniatura.

### 3.4 Regras da busca

`filterProjects` é uma função **pura** (`project_search.dart`):

- busca no `displayName`, ou seja, **no que o usuário vê**. Um item renomeado
  para "Pássaro azul" não é encontrado pelo antigo `IMG_001.jpg`;
- ignora maiúsculas e acentos: "passaro" encontra "Pássaro";
- cada palavra precisa aparecer, em qualquer ordem: "azul passaro" encontra
  "Pássaro azul";
- texto vazio ou só espaços mostra tudo, na ordem do último acesso.

A remoção de acentos é uma tabela pequena escrita à mão, com as letras do
português e algumas comuns em outras línguas latinas. Uma dependência a mais
não compensaria.

Sem resultados, a lista mostra "Nenhum desenho encontrado para “…”." Se o
histórico ficar vazio (último item excluído), a busca é limpa, para o
próximo desenho não aparecer "filtrado" por um texto invisível.

---

## 4. Organização (steering)

A `home_page.dart` passava das ~300 linhas recomendadas. Na Fase 4:

- a lista do histórico foi para `projects/widgets/project_history_list.dart`;
- as telas de boas-vindas, carregando e erro foram para
  `image_selection/presentation/widgets/home_status_views.dart`.

O comportamento dessas telas não mudou.

---

## 5. Testes

| Arquivo | O que cobre |
| --- | --- |
| `test/projects/project_names_test.dart` | prioridade de nomes, regras do `rename`, JSON com e sem `customName`, regras da busca |
| `test/projects/file_project_repository_test.dart` (grupo "renomeação") | nome gravado no disco, voltar ao original, não perder ajustes mais novos, não recriar projeto excluído |
| `test/widget_test.dart` (grupos "renomear" e "barra de pesquisa") | Editar à esquerda do Remover, salvar/cancelar/limpar, ordem mantida, filtro em tempo real, prioridade na busca, botão de limpar, `dispose` da Home |

## 6. Como testar no aparelho

1. Com alguns desenhos no histórico, toque no lápis de um deles e dê um nome
   novo. O nome deve mudar na hora, sem o item mudar de posição.
2. Feche o app pelos recentes e reabra: o nome continua.
3. Renomeie de novo deixando o campo em branco: volta o nome do arquivo.
4. Abra a galeria do aparelho: o arquivo original continua com o nome antigo.
5. Digite na busca com e sem acento ("passaro"/"pássaro"). Toque no X para
   limpar. Role a lista com o teclado aberto: ele deve fechar.
6. Abra um desenho renomeado, mexa nos ajustes e volte: o nome continua e os
   ajustes foram salvos.
