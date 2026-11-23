# 07 · Fase 6: tema e layout (Etapa 6A)

> **Nome do arquivo:** o pedido sugeria `docs/06-fase6-...`, mas o 06 já é
> o documento da Fase 5 (`docs/06-fase5-categorias-e-filtros.md`). Para
> manter a ordem de leitura, este é o **07**.

A Fase 6 é o **redesign visual**. A **Etapa 6A** cobre:

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
