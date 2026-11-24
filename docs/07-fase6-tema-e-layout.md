# 07 · Fase 6: tema e layout (Etapa 6A)

> **Nome do arquivo:** o pedido sugeria `docs/06-fase6-...`, mas o 06 já é
> o documento da Fase 5 (`docs/06-fase5-categorias-e-filtros.md`). Para
> manter a ordem de leitura, este é o **07**.

A Fase 6 é o **redesign visual**, em etapas:

- **Etapa 6A** (seções 1 a 5): tema claro/escuro e botão de sol/lua.
- **Etapa 6B** (seção 6): Home sem header, botão de sol/lua flutuando no
  canto, botões lado a lado sem imagem e a marca "Desenha A.I" desenhada.
- **Etapa 6C** (seção 7): ajustes finos de espaçamento e tamanho.

A **Etapa 6A** cobre:

- paleta própria nos modos **claro** e **escuro**;
- **primeira execução** seguindo o tema do sistema operacional;
- **escolha manual salva** no armazenamento local, 100% offline;
- **um único botão** de sol/lua animado no canto superior direito.

Nenhuma funcionalidade anterior mudou. Telas, textos e fluxos são os
mesmos; só a aparência ganhou identidade.

Arquivos da etapa:

```
lib/features/theme/
├─ app_palette.dart                      ← TODAS as cores do app
├─ app_theme.dart                        ← ThemeData claro e escuro (criados 1 vez)
├─ services/
│  ├─ theme_preference_store.dart        ← preferences.json
│  └─ theme_controller.dart              ← modo atual + alternar + salvar
└─ widgets/
   └─ theme_toggle_button.dart           ← botão único de sol/lua
```

---

## 1. Paleta (pegada "app de design")

> **Interpretação:** "Canvas" foi entendido como a estética do **Canva**
> (editor de design): fundo claro e limpo, violeta principal, turquesa de
> destaque e cantos bem arredondados. Os tons são **próprios**, não
> copiados. Se a referência for outra, a troca é toda em
> `app_palette.dart`.

| Papel | Claro | Escuro | Por quê |
| --- | --- | --- | --- |
| Principal (botões, seleção, foco) | violeta `#6A3DE8` | violeta claro `#B9A2FF` | o violeta escuro some num fundo escuro; a versão clara mantém o contraste |
| Destaque (secundária) | turquesa `#12B3A8` | turquesa claro `#5FE0D3` | |
| Fundo da tela | `#F6F5FB` (lilás bem claro) | `#14141C` (grafite azulado) | cards brancos "saltam" do fundo sem sombra; no escuro, grafite cansa menos que preto puro |
| Cards / superfícies | `#FFFFFF` | `#1D1D28` | |
| Texto | `#1C1A29` | `#EDEBF7` | |
| Texto secundário | `#5E5A72` | `#A9A6BD` | |
| Bordas finas | `#DCD8E8` | `#3A3A4C` | |

O estilo vale para os dois modos (`AppTheme._build`):

- **cantos arredondados** generosos: cards 16, botões e campos 12, chips em
  pílula;
- **bordas finas no lugar de sombras**: visual mais limpo e mais leve para
  pintar na GPU modesta do Galaxy Tab A;
- barra do topo **lisa**, da cor do fundo, sem a "sombra colorida" que o
  Material 3 aplica ao rolar;
- SnackBars flutuantes e arredondadas.

Um teste confere o **contraste** (razão do WCAG) do texto principal (> 7), do
texto secundário (> 4,5) e do texto sobre botões (> 4,5) nos dois modos.

O fundo da **Mesa de Luz** (branco/preto) e os controles escuros da tela de
desenho **não seguem o tema**, de propósito: eles fazem parte da função de
desenhar, e não da aparência.

### 1.1 Desempenho do tema

- `AppTheme.light` e `AppTheme.dark` são `static final`: criados **uma vez**.
  Trocar o tema só troca o objeto, sem recalcular cores nem estilos.
- O `MaterialApp` faz um "fade" de 250 ms entre os temas
  (`themeAnimationDuration`), que acompanha o botão.
- A Home é passada como `child` do `ValueListenableBuilder` que monta o
  `MaterialApp`. Trocar o tema **não recria a Home**: a busca, o filtro de
  categorias e a rolagem continuam como estavam (há um teste para isso).

---

## 2. Primeira execução e persistência

### 2.1 As três situações

| Situação | `ThemeMode` | O que aparece |
| --- | --- | --- |
| nunca tocou no botão (sem arquivo salvo) | `system` | o tema do aparelho (escuro → escuro) |
| escolheu **claro** | `light` | claro, mesmo com o aparelho no escuro |
| escolheu **escuro** | `dark` | escuro, mesmo com o aparelho no claro |

Depois da primeira escolha, o app **para de seguir o sistema**. Só muda se o
usuário tocar no botão de novo. Não existe um terceiro estado "voltar a
seguir o sistema", porque o pedido é um alternador de dois valores.

### 2.2 Onde fica salvo

```
app_flutter/
  preferences.json     ← {"schemaVersion": 1, "theme": "dark"}
  categories.json
  projects/
```

**Por que um arquivo, e não o pacote `shared_preferences`?** Para um único
valor, um JSON pequeno resolve com as **mesmas proteções** do resto do app,
sem dependência nova:

- gravação **atômica** (`.tmp` + renomear, docs/04, 1.5);
- **fila** de gravações: tocar várias vezes rápido grava na ordem, e a
  última escolha é a que fica;
- arquivo **corrompido** ou valor desconhecido = "nunca escolheu" (volta a
  seguir o sistema, sem travar o app).

Nenhuma permissão nova: é a mesma pasta privada do app.

### 2.3 Ler antes do primeiro quadro

```dart
// main.dart
final themeController = await ThemeController.load(
  FileThemePreferenceStore(file: File('.../preferences.json')),
);
runApp(DesenhaAiApp(..., themeController: themeController));
```

A preferência é lida **antes** do `runApp`. Se fosse lida depois, o app
abriria claro e "piscaria" para o escuro um instante depois. Ler um arquivo
de poucos bytes leva menos de 1 ms.

### 2.4 Alternar a partir do que está visível

```dart
// theme_controller.dart
Future<void> toggle(Brightness current) async {
  final next = current == Brightness.dark ? Brightness.light : Brightness.dark;
  _mode.value = ...;          // a tela muda NA HORA
  await store.save(next);     // grava em seguida
}
```

No primeiro toque o modo ainda é `system`. O controlador precisa saber o
brilho **visível** para ir para o oposto: aparelho escuro → toque → claro.
Se a gravação falhar (armazenamento cheio), o tema troca nesta sessão e só
não é lembrado na próxima.

---

## 3. Botão único de sol e lua

- **Onde:** o último item da barra da Home, no **canto superior direito**,
  depois do botão de Categorias.
- **O quê:** um `IconButton` que alterna claro ↔ escuro a cada toque. A dica
  diz o que o toque **vai** fazer ("Ativar modo escuro" / "Ativar modo
  claro").
- **Animação (350 ms):** o ícone que sai gira meia volta e encolhe enquanto o
  que entra gira e cresce, com um pequeno "quique" (`easeOutBack`). O sol é
  âmbar e a lua lilás.

### 3.1 Por que é leve

```dart
FadeTransition(opacity: ..., child:
  ScaleTransition(scale: ..., child:
    RotationTransition(turns: ..., child: Icon(Icons.light_mode))))
```

- `FadeTransition`, `ScaleTransition` e `RotationTransition` ligam a
  animação **direto na pintura**. A cada quadro **não há `build`**, nem do
  botão nem do resto da tela. O `setState` acontece uma vez por toque, só
  para trocar o texto da dica.
- São dois ícones de fonte: sem imagem, sem `CustomPainter`, sem pacote de
  animação.
- Um único `AnimationController` com `SingleTickerProviderStateMixin`: o
  relógio da animação pausa sozinho quando o botão sai da tela.

### 3.2 Por que o botão segue o modo, e não o `Theme`

O `MaterialApp` faz a transição entre temas em 250 ms e só troca o
**brilho** na metade dela. Se o botão se guiasse por `Theme.of(context)`:

- o sol/lua começaria a girar ~125 ms depois do toque (parece travado);
- os quadros intermediários poderiam até **inverter** a animação.

Por isso o botão escuta o **modo escolhido** (`controller.mode`) e, no modo
"sistema", o brilho do aparelho (`MediaQuery.platformBrightnessOf`), a
mesma regra que o `MaterialApp` usa. A resposta é imediata, e o botão também
reage se o tema do aparelho mudar enquanto o app segue o sistema.

### 3.3 Ciclo de vida

| Objeto | Dono | Liberado em |
| --- | --- | --- |
| `AnimationController` do sol/lua | `_ThemeToggleButtonState` | `dispose` do botão |
| ouvinte em `controller.mode` | `_ThemeToggleButtonState` | `dispose` (e trocado em `didUpdateWidget`) |
| `ThemeController` (com o `ValueNotifier`) | `main` (vive o app inteiro) | nos testes, `dispose` em cada teste |

Há um teste que sai da tela **no meio** da animação. Se o
`AnimationController` não fosse descartado, o Flutter acusaria "disposed
with an active Ticker".

---

## 4. Testes

`test/theme/theme_test.dart`:

| Grupo | O que cobre |
| --- | --- |
| paleta | identidade própria nos dois modos; contraste de texto (WCAG) |
| `FileThemePreferenceStore` | sem arquivo, grava e relê com um "app novo", última gravação vence, arquivo corrompido/valor desconhecido |
| `ThemeController` | começa no sistema sem preferência; começa na preferência salva; alterna a partir do brilho visível e salva; falha ao salvar não impede a troca |
| app e botão | 1ª execução com sistema escuro → escuro + lua; sistema claro → claro + sol; botão único no canto superior direito; cada toque alterna e anima (opacidade no meio da animação); escolha manual vence o sistema e sobrevive ao "reinício"; trocar o tema não recria a Home; sair no meio da animação sem vazamento |

Os testes das fases anteriores só ganharam o parâmetro `themeController`
(com o `fakeThemeController()` de `test/fakes.dart`).

## 5. Como testar no aparelho

1. Desinstale o app (para não haver preferência salva), coloque o aparelho
   no **modo escuro** e instale de novo: o app deve abrir escuro, com a lua.
2. Toque no botão: sol e lua giram, e o app fica claro.
3. Feche o app pelos recentes e reabra: continua **claro**, mesmo com o
   aparelho escuro.
4. Mude o tema do aparelho: o app **não** muda.
5. Toque várias vezes rápido no botão: a animação acompanha sem travar, e o
   último estado é o que fica ao reabrir.
6. No Galaxy Tab A, confira se a troca de tema não engasga a rolagem da
   lista.

---

## 6. Etapa 6B: Home sem header e marca desenhada

Arquivos da etapa:

```
lib/features/theme/widgets/desenha_ai_logo.dart        ← marca "Desenha A.I" (CustomPainter)
lib/features/image_selection/presentation/
├─ home_page.dart                                      ← sem AppBar; Stack + SafeArea
└─ widgets/home_status_views.dart                      ← boas-vindas: marca + botões lado a lado
lib/features/projects/widgets/project_history_list.dart ← marca no topo da listagem
```

### 6.1 Header removido por completo

A Home **não tem mais `AppBar`**: sumiram a barra, o título `desenha_ai` e o
ícone de etiqueta ("Categorias") que ficava nela.

```
ANTES (6A)                                  AGORA (6B)
┌───────────────────────────────────┐       ┌───────────────────────────────────┐
│ desenha_ai            🏷️   ☀️      │       │                              ☀️    │
├───────────────────────────────────┤       │           Desenha A.I              │
│ [ Novo desenho ]                  │       │ [ Novo desenho ]                  │
│ Continuar desenhando              │       │ Continuar desenhando              │
│ [🔍 Pesquisar desenhos ]          │       │ [🔍 Pesquisar desenhos ]          │
│ …                                 │       │ … (igual)                         │
```

Tudo **abaixo da barra de pesquisa ficou intacto**: faixa de categorias,
cards, editar, remover, filtro e busca têm o mesmo código e os mesmos dados.

**Para onde foi o acesso à tela "Categorias"?**

| Estado da Home | Caminho |
| --- | --- |
| sem imagem | botão **Categorias** ao lado de "Escolher imagem" (6.3) |
| com listagem | botão **Categorias** da faixa abaixo da busca (Etapa 5B), que também cria e remove |

### 6.2 Botão de sol/lua flutuando no canto superior direito

```dart
// home_page.dart
Scaffold(
  body: Stack(children: [
    SafeArea(child: AnimatedSwitcher(child: content)),   // estado da Home
    SafeArea(child: Align(                               // botão por cima
      alignment: Alignment.topRight,
      child: Padding(padding: EdgeInsets.all(8),
        child: ThemeToggleButton(controller: ...)),
    )),
  ]),
)
```

- O botão fica numa **`SafeArea` própria**: longe da barra de status, de
  entalhes e de câmeras frontais.
- Fica **fora** do `AnimatedSwitcher`: aparece igual em todos os estados
  (boas-vindas, carregando, erro, listagem) e não pisca quando a Home troca
  de estado.
- O botão em si não mudou (animação, persistência e `dispose` da 6A).

### 6.3 Barra de status sem AppBar

Era a `AppBar` que dizia ao Android a cor dos ícones da barra de status
(relógio, bateria). Sem ela, os ícones poderiam ficar brancos sobre o fundo
claro. A Home agora faz isso explicitamente:

```dart
AnnotatedRegion<SystemUiOverlayStyle>(
  value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
      .copyWith(statusBarColor: Colors.transparent),
  child: Scaffold(...),
)
```

Ícones escuros no tema claro e claros no escuro, com a barra transparente
(o fundo do app aparece por trás).

### 6.4 Botões lado a lado no estado sem imagem

```
            Desenha A.I
   Escolha uma imagem de referência
   Use uma foto ou desenho salvo…

 [ 🖼  Escolher imagem ] [ 🏷  Categorias ]
```

- Mesmo **molde**: os dois são `FilledButton.icon`, com a mesma altura
  (56 dp) e o mesmo estilo.
- `Expanded` nos dois: dividem a largura igualmente e cabem lado a lado até
  num celular em pé (há um teste com 360 dp).
- O botão de categoria tem o **ícone de etiqueta** e abre a tela
  "Categorias" (criar e remover).

### 6.5 "Desenha A.I" em letras desenhadas

A marca é **desenhada traço a traço** por um `CustomPainter`, sem fonte e
sem imagem.

**Como as letras são feitas:**

1. Cada letra é uma lista de **traços**, e cada traço uma lista de
   **pontos** por onde a "caneta" passa (coordenadas em unidades: y = 0 é o
   topo das maiúsculas, y = 1 a linha de base).
2. Os pontos são ligados por **curvas quadráticas** que passam pelo meio
   entre um ponto e o próximo. O traço fica sem quinas, como feito à mão.
3. Dois passes de pintura:
   - um traço fino, transparente e levemente deslocado, que lembra **lápis**
     de esboço;
   - por cima, o traço principal ("tinta") com **degradê** violeta →
     turquesa, as cores do tema.
4. Pontas e junções **redondas** (`StrokeCap.round`): o ponto do "A.I" é um
   traço curtíssimo que vira uma gota de caneta.

**Por que não uma fonte manuscrita?** Uma fonte custa centenas de KB no APK
e cobre milhares de letras; usamos 9. Um caminho vetorial próprio é leve,
100% offline e nítido em qualquer tamanho.

**Desempenho:**

| Cuidado | Efeito |
| --- | --- |
| contorno montado **uma vez** (`static final`) em unidades | pintar é só `scale` + `drawPath` |
| `shouldRepaint` compara só as **cores** | só repinta ao trocar o tema |
| `RepaintBoundary` em volta | rolar a lista ou digitar na busca não repinta a marca |
| `Semantics(label: 'Desenha A.I')` | o leitor de tela lê a marca como texto |

**Onde aparece:**

| Tela | Posição |
| --- | --- |
| sem imagem | no centro, acima de "Escolha uma imagem de referência", no lugar do ícone grande das fases anteriores |
| com listagem | centralizada no **topo da lista**, rolando junto com ela, com margem de 56 dp nas laterais para não ficar sob o botão de sol/lua |

Na listagem, a marca **não** fica fixa no meio da tela: fixa, ficaria por
cima dos cards e atrapalharia a leitura e os toques.

### 6.6 Testes

`test/theme/home_layout_test.dart` (para os estados **sem imagem** e **com
listagem**):

| O que cobre |
| --- |
| sem `AppBar`/`SliverAppBar`, sem o título `desenha_ai` e sem o ícone "Categorias" do header |
| botão de sol/lua no canto superior direito, dentro de `SafeArea`, e alternando o tema |
| marca "Desenha A.I" presente, desenhada com o `DesenhaAiLogoPainter` (sem texto de fonte), centralizada e sem sobrepor o botão |
| sem imagem: "Escolher imagem" e "Categorias" na mesma linha, mesmo tamanho e tipo, ícone de etiqueta, abre a tela de categorias, cabe em 360 dp |
| com listagem: busca, faixa, cards, editar, excluir, badge e "Novo desenho" preservados; marca acima da busca; busca e seletor funcionando |
| marca e ícones da barra de status acompanham o tema |
| `shouldRepaint` só quando as cores mudam |

Testes anteriores ajustados: o da posição do botão (6A) não compara mais com
o ícone do header, e os da tela "Categorias" (5A) abrem a tela pelo botão
novo ou diretamente.

### 6.7 Como testar no aparelho

1. Sem desenhos: a Home mostra a marca no centro e os dois botões lado a
   lado. "Categorias" abre a tela de categorias.
2. Com desenhos: a marca fica no topo, sem barra. Busca, faixa e cards
   funcionam como antes.
3. O sol/lua continua no canto superior direito nos dois estados, sem ficar
   sob a câmera frontal do RedMagic nem sob a barra de status.
4. Alterne o tema: a marca muda de cor, e os ícones do relógio/bateria
   continuam visíveis.
5. Role a lista no Galaxy Tab A: a marca sobe junto, sem engasgar.

---

## 7. Etapa 6C: ajustes finos de espaçamento e tamanho

| Ajuste | Antes (6B) | Agora (6C) | Onde |
| --- | --- | --- | --- |
| Título da listagem (marca "Desenha A.I") | 12 dp do topo | **42 dp** (+30) | `ProjectHistoryList.titleTopInset` |
| Margem lateral do título | 56 dp | **72 dp** | `ProjectHistoryList.titleSideInset` |
| Botão de sol/lua: área de toque | 48 dp (padrão do `IconButton`) | **56 dp** | `ThemeToggleButton.size` |
| Botão de sol/lua: ícone | 24 dp | **30 dp** | `ThemeToggleButton.iconSize` |
| Botão de sol/lua: distância do topo | 8 dp | **28 dp** (+20) | `HomePage.themeButtonInsets` |
| Botão de sol/lua: distância da direita | 8 dp | 8 dp | (igual) |

Todas as medidas são **constantes com nome**, e não números soltos no
layout: dá para ajustar de novo mudando um lugar só, e os testes conferem os
mesmos valores.

> **Título:** desde a Etapa 6B, o "título" da tela de listagem é a marca
> "Desenha A.I" no topo da lista. É ela que desceu 30 dp.

### 7.1 Por que a margem lateral do título aumentou

Com o botão de sol/lua maior (56 dp) e mais baixo (topo em 28 dp), ele fica
na mesma altura da marca. Num celular em pé (360 dp), a margem de 56 dp
deixava a marca encostar no botão. Com 72 dp sobra espaço (há um teste com
360 dp).

### 7.2 O botão desce sem mexer no layout da tela inicial

A regra crítica era: descer o botão **não pode empurrar nem desalinhar**
nada da tela inicial. Por isso ele mudou de `Align` para `Positioned`:

```dart
// home_page.dart
Stack(children: [
  SafeArea(child: AnimatedSwitcher(child: content)),  // layout central
  Positioned(                                         // camada do botão
    top: 0,
    right: 0,
    child: SafeArea(
      left: false,
      bottom: false,
      child: Padding(
        padding: HomePage.themeButtonInsets,          // top: 28, right: 8
        child: ThemeToggleButton(...),
      ),
    ),
  ),
])
```

- O `Positioned` ocupa **só o canto**. O `Align` anterior ocupava a tela
  inteira (mesmo sem desenhar nada) e ficava na frente de todo o conteúdo.
- O botão está numa **camada separada** do `Stack`: o tamanho e a posição
  dele não entram no cálculo do layout do conteúdo. O bloco central (marca,
  textos e os dois botões) continua centralizado nas duas direções, como
  antes.
- A `SafeArea` continua valendo: num aparelho com barra de status de 24 dp,
  o botão fica em 24 + 28 dp (há um teste para isso).
- "Todas as telas onde ele aparece": o botão existe só na Home, em todos os
  estados dela (sem imagem, carregando, erro e listagem). Como fica numa
  camada única, fora do `AnimatedSwitcher`, o ajuste vale para todos.

### 7.3 Por que 56 dp

48 dp é o mínimo recomendado pelo Material para alvos de toque. 56 dp dá
folga para o polegar no RedMagic e para acertar sem olhar com o Galaxy Tab A
apoiado na mesa. O sol e a lua cresceram junto (30 dp) para continuar
proporcionais à área de toque. A animação não mudou: as transições na pintura
continuam sem `build` a cada quadro.

### 7.4 Testes

Em `test/theme/home_layout_test.dart`:

| Teste | O que confere |
| --- | --- |
| título da listagem | topo da marca em 42 dp |
| botão maior | área de 56 × 56 dp, ícone de 30 dp |
| `SafeArea` | com 24 dp de barra de status, o botão fica em 52 dp |
| tela inicial intacta | o botão está num `Positioned(top: 0, right: 0)` fora da tela inicial; a tela inicial ocupa a área inteira; o bloco central fica centralizado nas duas direções; botões lado a lado e iguais; o botão não fica por cima do bloco central |
| 360 dp | título e botão não se encostam, sem overflow |

O teste de posição da 6B foi atualizado: topo exatamente em 28 dp, a 8 dp da
direita, com 56 × 56 dp.

### 7.5 Como testar no aparelho

1. Com desenhos: a marca fica mais afastada do topo, sem encostar no botão.
2. O sol/lua está maior e um pouco mais baixo, nos dois estados da Home.
3. Sem desenhos: a marca, os textos e os dois botões continuam exatamente no
   centro da tela.
4. No RedMagic, o botão não fica sob a câmera frontal nem sob a barra de
   status.

## 8. Etapa 6E: nenhuma tela com `AppBar` e botão sol/lua maior

### 8.1 Headers removidos de todas as páginas
A Home (6B) e a tela de desenho já não tinham `AppBar`. Restavam duas telas:

| Tela | Antes (na `AppBar`) | Agora (no corpo) |
| --- | --- | --- |
| Categorias | título "Categorias" e seta de voltar | `PageHeader` com título e voltar; o botão "Nova categoria" continua flutuante |
| Filtrar por categoria | título, "Limpar" e "+" (nova categoria) | `PageHeader` com título, "Limpar" e "+" à direita; "X" de fechar |

Nenhuma ação foi removida. O novo widget compartilhado
`lib/core/widgets/page_header.dart` (usado por duas telas, então vai em
`core/`) mostra:

- seta de voltar (`BackButton`) se existe tela anterior, ou "X"
  (`CloseButton`) se a rota é `fullscreenDialog`, como o seletor de
  categorias. É o mesmo comportamento automático que a `AppBar` tinha;
- o título em `headlineSmall` negrito, sem faixa de fundo nem sombra, no
  mesmo estilo da marca da Home;
- as ações, alinhadas à direita.

O cabeçalho fica dentro da `SafeArea`, então não encosta na barra de status.
Por não ter `AppBar`, ele não "rola por baixo" nem pinta fundo: é só um
`Row` leve, sem custo extra de pintura no Galaxy Tab A.

### 8.2 Botão de sol/lua maior
`ThemeToggleButton`: área de toque de 56 para **64 dp** e sol/lua de 30 para
**36 dp**. O botão existe numa única camada da Home (todos os estados dela),
então o novo tamanho vale onde ele aparece. A animação não mudou
(`Rotation`/`Scale`/`FadeTransition`, 350 ms, sem `build` por quadro).

### 8.3 Testes
- `test/theme/home_layout_test.dart`: área de 64 x 64 dp, ícone de 36 dp,
  topo em 28 dp, sem sobreposição com o título, nem em 360 dp de largura.
- `test/projects/*`: os testes que fecham o seletor pelo "X" e abrem a tela de
  Categorias continuam passando com o cabeçalho no corpo.

### 8.4 Como testar no aparelho
1. Abra "Categorias" e o seletor de filtro: sem barra no topo, título grande
   e seta de voltar (ou "X" no seletor); "Limpar" e "+" funcionam.
2. O sol/lua está visivelmente maior na Home e continua girando suave.

## 9. Etapa 6F: seta + título centralizado, sol/lua em todas as telas

Corrige o que não ficou bom na 6E: o `PageHeader` da 6E era uma `Row`
(voltar, título à esquerda, ações) que ainda parecia uma `AppBar`, e o
seletor de categorias mostrava "X".

### 9.1 Novo `PageHeader` (sem nenhuma faixa)
`lib/core/widgets/page_header.dart`, usado por **Categorias** e **Filtrar por
categoria**. Duas linhas, sem fundo, borda ou sombra:

1. Seta de voltar (`Icons.arrow_back`, 56 dp) à esquerda e o botão de sol/lua
   à direita, a `PageHeader.topInset` (28 dp) do topo da `SafeArea`. É a
   mesma altura do botão na Home (`HomePage.themeButtonInsets` agora usa
   essa constante), então o sol/lua não "pula" ao trocar de tela.
2. O título centralizado, em `headlineMedium` negrito, 20 dp abaixo dessa
   linha (topo em ~112 dp, fora da faixa de 56 dp de uma `AppBar`).

Como o título tem uma linha só dele, ele nunca colide com a seta nem com o
sol/lua, nem em 360 dp. A seta usa `maybePop`, que respeita um `PopScope`.

O seletor de categorias deixou de ser `fullscreenDialog`: com a seta no lugar
do "X", a animação lateral de navegação combina melhor do que a de baixo para
cima. Voltar pela seta continua descartando as marcações, como o "X" fazia.

### 9.2 Seletor de categorias: botões abaixo da pesquisa
Logo abaixo da pesquisa, à direita: **Limpar** (texto, ação secundária) e
**Adicionar categoria** (preenchido). O "+" solto do topo saiu.

- "Adicionar categoria" usa o mesmo molde dos botões da tela sem imagem
  ("Escolher imagem" e "Categorias"): 56 dp de altura e texto `titleMedium`.
  O molde foi para `lib/core/widgets/large_button_style.dart`
  (`largeButtonStyle`), porque agora tem dois usos reais.
- Os dois ficam num `Wrap` alinhado à direita: num celular estreito, se não
  couberem lado a lado, o segundo desce em vez de dar overflow.
- A tela inteira virou um `CustomScrollView` (cabeçalho, pesquisa, botões e a
  lista como slivers). Com o título mais baixo, um celular deitado com o
  teclado aberto não teria altura para tudo fixo; rolando juntos, não há
  overflow. A lista continua preguiçosa (`SliverList.list`) e só ela escuta o
  texto da pesquisa.

### 9.3 Sol/lua em todas as telas
| Tela | Onde fica |
| --- | --- |
| Home (todos os estados) | canto superior direito, camada própria (desde a 6B) |
| Categorias | canto superior direito, no `PageHeader` |
| Filtrar por categoria | canto superior direito, no `PageHeader` |
| Desenho | canto superior direito, à esquerda do cadeado |

Na tela de desenho o cadeado continua no canto (é o controle mais importante
ali). O sol/lua fica 8 dp à esquerda dele, com o mesmo fundo escuro
translúcido, para ficar legível sobre a câmera. Ele some quando a tela é
travada, como os outros controles. É uma camada separada no `Stack` (e não
uma `Row` com o cadeado) para não mexer no estado do `LockButton`.

As telas recebem o `ThemeController` pelo construtor (`themeController:`),
como os outros serviços, então os testes usam o `fakeThemeController()`.

### 9.4 Home: marca 30 dp abaixo do sol/lua
Na listagem, `ProjectHistoryList.titleTopInset` passou de 42 para
`PageHeader.topInset + ThemeToggleButton.size + 30` = 28 + 64 + 30 =
**122 dp**. A marca e tudo abaixo dela (Novo desenho, busca, faixa, cards)
descem juntos, porque estão no mesmo `CustomScrollView`, que rola. Por isso
não há overflow e nada muda no custo de rolagem. A tela sem imagem continua
centralizada como antes.

### 9.5 Testes
- `test/theme/screens_without_header_test.dart` (novo):
  - Categorias: sem `AppBar` nem "X", com seta; título centralizado com topo
    abaixo de 100 dp e a seta acima dele; sol/lua 64 x 64 a 28 dp do topo, a
    8 dp da direita, sem encostar em nada; a seta volta; o sol/lua troca o
    tema; sem overflow em 740 x 360.
  - Seletor: seta no lugar do "X", sol/lua presente, título centralizado;
    "Limpar" e "Adicionar categoria" abaixo da pesquisa, alinhados à
    direita (Adicionar na margem, Limpar 8 dp à esquerda), com 56 dp; "Adicionar categoria" abre o formulário; sem overflow num
    celular deitado.
  - Desenho: sol/lua à esquerda do cadeado, na mesma altura, e some ao
    travar.
- `test/theme/home_layout_test.dart`: a marca fica exatamente 30 dp abaixo
  da base do sol/lua (topo em 122 dp) e "Novo desenho" continua abaixo dela.
- `test/projects/category_filter_ui_test.dart`: fechar o seletor agora é
  pela seta (`PageHeader.backButtonKey`).

### 9.6 Como testar no aparelho
1. Categorias e Filtrar por categoria: sem barra no topo; seta à esquerda e
   sol/lua à direita na mesma linha; título centralizado bem abaixo.
2. No seletor: "Limpar" e "Adicionar categoria" à direita, logo abaixo da
   pesquisa.
3. Tela de desenho: o sol/lua aparece ao lado do cadeado e some ao travar.
4. Home com desenhos: a marca fica cerca de 30 dp abaixo do sol/lua.

## 10. Seletor de categorias: "Limpar" à esquerda e "Selecionar todas"

Ajustes no seletor "Filtrar por categoria" (`category_filter_screen.dart`),
depois da Etapa 6F.

### 10.1 "Limpar" na esquerda, no mesmo molde do "Adicionar"
Na linha abaixo da pesquisa, "Limpar" fica na margem ESQUERDA e
"Adicionar categoria" na DIREITA. Na 6F os dois ficavam juntos à direita.

- **Por que separar:** com os dois nas pontas, um toque destinado a um não
  acerta o outro, e a ação que desfaz (limpar) fica longe da que cria.
- **Mesmo molde:** os dois têm 56 dp de altura, texto `titleMedium`, o mesmo
  recuo e os mesmos cantos do tema. "Adicionar" é preenchido
  (`largeButtonStyle`) e "Limpar" é contornado (`largeOutlinedButtonStyle`,
  novo em `lib/core/widgets/large_button_style.dart`). Assim os dois
  combinam, mas a ação principal continua em destaque.
- **Comportamento igual:** "Limpar" desmarca tudo no rascunho, como antes, e
  fica desabilitado quando não há nada marcado. A pesquisa não é apagada.
- **Celular estreito:** a linha é uma `Row` com `Flexible` no "Adicionar". Se
  faltar espaço, o texto dele ganha "…" em vez de dar overflow, e um vão
  mínimo de 16 dp separa os dois.

### 10.2 "Selecionar todas" logo abaixo de "Sem categoria"
Uma linha da lista, com o mesmo alvo de toque das opções ao redor, entre
"Sem categoria" e as categorias.

| Situação | O que o toque faz | Subtítulo |
| --- | --- | --- |
| Pesquisa vazia | marca TODAS as categorias | "Marca todas as categorias" |
| Pesquisa com texto | marca só as categorias EXIBIDAS | "Marca as N categorias da pesquisa" (ou "a categoria", se for uma) |
| Todas as exibidas já marcadas | nada (a linha fica desabilitada) | o mesmo |
| Nenhuma categoria exibida | a linha não aparece | (nada) |

Regras:
- **Soma, nunca desmarca.** Uma categoria marcada antes e escondida pela
  pesquisa continua marcada. "Sem categoria" também não muda: é uma opção
  separada, com a sua própria caixa.
- **Rascunho:** como as outras marcações, só vale para o histórico depois de
  "Aplicar".

A lógica está no modelo (`CategoryFilter.selectAll` e `containsAll`), que é
puro e tem teste de unidade. Quando nada muda, `selectAll` devolve a MESMA
instância, e a tela pula o `setState`: um toque sem efeito não reconstrói
nada.

### 10.3 Testes
- `test/projects/category_filter_test.dart` (unidade): `selectAll` marca
  todas; soma sem desmarcar categorias nem "Sem categoria"; devolve a mesma
  instância quando nada muda; `containsAll`.
- `test/projects/category_filter_actions_test.dart` (widget, novo):
  - "Limpar" a 16 dp da margem esquerda e "Adicionar" a 16 dp da direita, na
    mesma linha, com pelo menos 16 dp entre eles;
  - "Limpar" é `OutlinedButton`, "Adicionar" é `FilledButton`, os dois com
    56 dp e o mesmo tamanho mínimo, recuo e fonte;
  - "Limpar" continua desmarcando tudo e fica desabilitado sem seleção;
  - "Selecionar todas" encosta na base de "Sem categoria" e vem antes da
    primeira categoria;
  - sem pesquisa, marca as 3 categorias (e não "Sem categoria"), fica
    desabilitado e, aplicado, mostra só os desenhos com categoria;
  - com a pesquisa "ais", marca Animais e Paisagens e mantém Retratos se ela
    já estava marcada (ou a deixa de fora se não estava);
  - subtítulo no singular com uma categoria; some sem categorias ou com
    pesquisa sem resultado.
- `test/theme/screens_without_header_test.dart`: o teste da 6F deixou de
  exigir "Limpar" colado no "Adicionar".

### 10.4 Como testar no aparelho
1. Abra o seletor: "Limpar" na esquerda, "Adicionar categoria" na direita,
   do mesmo tamanho.
2. Toque em "Selecionar todas": todas as categorias ficam marcadas e o
   "Aplicar" mostra a contagem.
3. Pesquise parte de um nome e toque em "Selecionar todas": só as exibidas
   são marcadas; ao apagar a pesquisa, as marcadas antes continuam.
