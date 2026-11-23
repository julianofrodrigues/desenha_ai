# 07 · Fase 6: tema e layout (Etapa 6A)

> **Nome do arquivo:** o pedido sugeria `docs/06-fase6-...`, mas o 06 já é
> o documento da Fase 5 (`docs/06-fase5-categorias-e-filtros.md`). Para
> manter a ordem de leitura, este é o **07**.

A Fase 6 é o **redesign visual**, em etapas:

- **Etapa 6A** (seções 1 a 5): tema claro/escuro e botão de sol/lua.
- **Etapa 6B** (seção 6): Home sem header, botão de sol/lua flutuando no
  canto, botões lado a lado sem imagem e a marca "Desenha A.I" desenhada.

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
