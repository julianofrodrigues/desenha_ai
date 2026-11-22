# 03 · Fase 2: câmera, gestos e rebuilds

Este documento explica os três conceitos novos da Fase 2, sempre apontando
para o código real do `desenha_ai`.

Arquivos da fase:

```
lib/features/drawing/
├─ models/
│  ├─ drawing_mode.dart        ← enum Câmera / Mesa de Luz
│  └─ overlay_transform.dart   ← posição, zoom, rotação, espelho (imutável)
├─ services/
│  ├─ camera_service.dart      ← ciclo de vida da câmera, atrás de uma interface
│  └─ screen_wake_lock.dart    ← tela sempre acesa durante o desenho
├─ widgets/
│  ├─ camera_layers.dart       ← preview em tela cheia + avisos (sem permissão)
│  ├─ reference_overlay.dart   ← imagem + gestos multitoque
│  ├─ drawing_toolbar.dart     ← opacidade, modo, lanterna, espelhar, resetar
│  └─ lock_button.dart         ← trava (segurar 1,5 s ou toque duplo)
└─ screens/
   └─ drawing_screen.dart      ← monta as camadas e cuida do ciclo de vida
```

---

## 1. Ciclo de vida da câmera

### 1.1 Permissão no `AndroidManifest.xml`

O Android exige duas coisas para usar a câmera:

1. **Declarar** a permissão no manifest (`android/app/src/main/AndroidManifest.xml`):

   ```xml
   <uses-permission android:name="android.permission.CAMERA" />
   ```

2. **Pedir em tempo de execução** (Android 6+). O usuário vê o diálogo
   "Permitir que desenha_ai tire fotos e grave vídeos?". O plugin `camera`
   faz isso sozinho dentro de `controller.initialize()`.

Também ajustamos o que o plugin traz:

- O plugin declara `RECORD_AUDIO` e `WRITE_EXTERNAL_STORAGE` (para gravar
  vídeo). Não usamos nenhuma das duas, então as removemos com
  `tools:node="remove"`. Os manifests de todos os plugins são **mesclados**
  no APK final, e `tools:` é como o app dá a última palavra.
- Declarar `CAMERA` faz o Android tratar a câmera como **obrigatória**: a
  Play Store esconderia o app de aparelhos sem câmera. Com
  `<uses-feature ... android:required="false" />`, a câmera vira opcional,
  e o app continua útil no Modo Mesa de Luz.

### 1.2 `CameraController`: abrir, usar, fechar

```dart
// lib/features/drawing/services/camera_service.dart
controller = CameraController(
  back,                    // câmera traseira
  ResolutionPreset.high,   // ~720p: nítido e leve para o Galaxy Tab A
  enableAudio: false,      // sem microfone
);
await controller.initialize(); // pede permissão + abre o hardware
// ... CameraPreview(controller) mostra a imagem ao vivo ...
await controller.dispose();    // libera o hardware
```

Por que tanto cuidado com `dispose()`?

- A câmera é um recurso **exclusivo**: enquanto o app a segura, outros apps
  não conseguem usá-la.
- Ela mantém buffers de vídeo na memória e consome bateria. No Galaxy Tab A,
  esquecer uma câmera aberta faz o sistema matar o app por falta de memória.

Os quadros de vídeo **não passam pelo `build`**. O `CameraPreview` mostra
uma `Texture` que o Android atualiza direto na GPU. Por isso a tela só é
reconstruída quando o *estado* da câmera muda (ligou, desligou, deu erro),
nunca a cada quadro.

### 1.3 Estados da câmera

Assim como na Home, os estados são uma `sealed class`:

```
CameraOff ──start()──► CameraStarting ──ok──► CameraReady(controller)
    ▲                        │
    │                        ├─ permissão negada ─► CameraPermissionDenied
    └────── stop() ──────────┴─ outro erro ───────► CameraUnavailable
```

A UI faz um `switch` sobre o estado. O compilador garante que o caso
"permissão negada" foi tratado. Nesse caso, um cartão oferece **"Usar Mesa
de Luz"** como ação principal, para o usuário nunca ficar travado.

### 1.4 Corrida entre `start()` e `stop()`

Abrir a câmera leva centenas de milissegundos. Se o usuário tocar
Câmera → Mesa de Luz → Câmera rapidamente, a primeira abertura pode terminar
**depois** do `stop()`. Sem proteção, exibiríamos (ou vazaríamos) uma câmera
que deveria estar fechada.

A solução é um contador de geração:

```dart
final generation = ++_generation;   // "esta é a tentativa nº N"
await controller.initialize();
if (generation != _generation) {    // alguém chamou stop() nesse meio-tempo
  await controller.dispose();       // descarta o resultado obsoleto
  return;
}
```

### 1.5 `WidgetsBindingObserver`: minimizar e voltar

Um `State` pode "assinar" eventos do app inteiro:

```dart
// lib/features/drawing/screens/drawing_screen.dart
class _DrawingScreenState extends State<DrawingScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);     // assina
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);  // cancela (obrigatório!)
    ...
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { ... }
}
```

Os estados, do mais ativo ao menos ativo:

| Estado | Quando acontece | O que fazemos |
| --- | --- | --- |
| `resumed` | app visível e com foco | religa a câmera **se** fomos nós que a desligamos |
| `inactive` | diálogo de permissão, barra de notificações puxada | nada |
| `hidden` | app saiu da tela (botão home, outro app, tela apagou) | **desliga a câmera** |
| `paused` | em segundo plano | nada (já desligamos em `hidden`) |
| `detached` | o motor do Flutter está sendo encerrado | nada |

Por que `hidden`, e não `inactive` como em muitos tutoriais? Porque o
**diálogo de permissão da câmera** coloca o app em `inactive`. Se
fechássemos a câmera ali, ela seria reaberta ao voltar, pedindo permissão de
novo, e o ciclo se repetiria.

Também só religamos se a câmera estava funcionando antes de sair. Se a
permissão tinha sido negada, não pedimos de novo sozinhos; o usuário usa o
botão "Tentar novamente".

### 1.6 Quem cria, descarta

A `DrawingScreen` recebe uma **fábrica** (`cameraServiceFactory`), não um
serviço pronto. Ela cria o serviço no início e o descarta no `dispose()`.
Assim a câmera existe só enquanto a tela de desenho existe. Nos testes, a
fábrica devolve uma câmera falsa (`test/fakes.dart`).

---

## 2. Transformações matriciais e gestos multitoque

### 2.1 O que é uma `Matrix4`

Mover, girar e escalar são **transformações geométricas**. Uma matriz 4x4
consegue representar qualquer combinação delas num único objeto, e a GPU
aplica essa matriz a cada pixel de graça.

O widget `Transform` recebe uma `Matrix4` e a aplica ao filho **só na
pintura**: o layout não muda, e por isso é barato.

### 2.2 A ordem importa

```dart
// lib/features/drawing/models/overlay_transform.dart
Matrix4 toMatrix() {
  return Matrix4.identity()
    ..translateByDouble(offset.dx, offset.dy, 0, 1)                // 3º: desloca
    ..rotateZ(rotation)                                            // 2º: gira
    ..scaleByDouble(flipped ? -scale : scale, scale, 1, 1);        // 1º: escala/espelha
}
```

Cada chamada multiplica a matriz pela direita, então, para um ponto da
imagem, a **última** operação escrita é a **primeira** aplicada. A sequência
"escala → gira → desloca" faz a imagem girar e crescer em volta do **próprio
centro** e depois ir para a posição. Na ordem inversa, ela giraria em volta
do centro da tela, como um planeta em órbita.

Detalhes:

- `alignment: Alignment.center` no `Transform` põe a origem (0, 0) no centro
  da imagem.
- Espelhar é só escalar o eixo X por −1. Por vir antes da rotação, girar com
  os dedos continua no sentido intuitivo mesmo com a imagem espelhada.

### 2.3 `GestureDetector` com `onScale*` (e por que não `InteractiveViewer`)

O `ScaleGestureRecognizer` do Flutter reconhece, num só gesto:

- arrastar com 1 dedo (`focalPoint` muda; `scale` = 1, `rotation` = 0);
- pinça e giro com 2 dedos (`scale` e `rotation` mudam junto com o
  `focalPoint`).

```dart
// lib/features/drawing/widgets/reference_overlay.dart
onScaleStart: (d) {
  _gestureStart = widget.transform.value;   // estado no início do gesto
  _gestureStartFocalPoint = d.focalPoint;
},
onScaleUpdate: (d) {
  widget.transform.value = _gestureStart!.applyGesture(
    pan: d.focalPoint - _gestureStartFocalPoint,
    scaleFactor: d.scale,        // acumulado desde o início
    rotationDelta: d.rotation,   // acumulado desde o início
  );
},
```

`ScaleUpdateDetails.scale` e `.rotation` são **acumulados desde o início do
gesto**, e não desde o último evento. Por isso calculamos sempre a partir do
estado inicial, em vez de somar pequenos passos, o que acumularia erro de
arredondamento. Quando um dedo entra ou sai no meio do gesto, o Flutter
chama `onScaleStart` de novo, e guardamos o estado atual como novo início
(sem "pulos").

**Por que não `InteractiveViewer`?** Ele é ótimo para "dar zoom num mapa",
mas não suporta rotação, controla a matriz internamente (difícil de salvar
na Fase 3 e de resetar exatamente) e tem limites de borda pensados para
navegação. Com `GestureDetector` + nosso próprio modelo, temos rotação,
espelho, limites de zoom e um objeto simples para salvar depois.

Os gestos valem na **tela inteira** (`HitTestBehavior.opaque`), não só sobre
a imagem. Assim dá para ajustar uma imagem pequena ou que saiu da tela.

### 2.4 Lógica fora do widget = testável

Toda a matemática está em `OverlayTransform.applyGesture` e `toMatrix`, sem
nenhum widget. `test/drawing/overlay_transform_test.dart` testa limites de
zoom, normalização do ângulo, reset e espelhamento sem abrir nenhuma tela.

---

## 3. `ValueNotifier` em vez de `setState` na tela inteira

### 3.1 O problema

Arrastar o slider de opacidade gera um evento por quadro (60 a 120 por
segundo no RedMagic). Gestos na imagem também. Se cada evento chamasse
`setState` na `DrawingScreen`, o Flutter reconstruiria **tudo** a cada
quadro: o fundo da câmera, a barra de botões, o painel de status, a trava...
Isso gasta CPU à toa e, no Galaxy Tab A, aparece como engasgos (*jank*).

### 3.2 A solução

Um `ValueNotifier<T>` guarda um valor e avisa quem estiver ouvindo quando ele
muda. O `ValueListenableBuilder` reconstrói **só o próprio builder**:

```dart
// Na tela: o estado vive em notifiers.
final _opacity = ValueNotifier(0.5);

// No slider (drawing_toolbar.dart): só o Slider é reconstruído.
ValueListenableBuilder<double>(
  valueListenable: opacity,
  builder: (context, value, _) => Slider(
    value: value,
    onChanged: (v) => opacity.value = v,   // sem setState!
  ),
);

// Na imagem (reference_overlay.dart): só o widget Opacity é reconstruído.
ValueListenableBuilder<double>(
  valueListenable: widget.opacity,
  builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
  child: image,   // ← montado uma vez, reaproveitado a cada quadro
);
```

O parâmetro **`child`** é o detalhe mais importante: o que é passado ali é
construído **uma vez** e entregue pronto ao builder. A imagem decodificada
nunca é reconstruída ao mexer na opacidade nem ao arrastar.

O que reconstrói quando cada coisa muda:

| Muda | Reconstrói |
| --- | --- |
| opacidade | `Slider`, texto "50%", widget `Opacity` |
| posição/zoom/rotação | só o widget `Transform` |
| espelhar | `Transform` + botão de espelhar (que só chama `setState` quando `flipped` muda de fato) |
| modo Câmera/Mesa de Luz | fundo, seletor de modo, botões que dependem do modo |
| trava | a pilha de controles (as camadas pesadas passam pelo `child`) |

### 3.3 Outras peças que ajudam

- **Modelo imutável com `==`** (`OverlayTransform`): o `ValueNotifier` só
  avisa quando o novo valor é **diferente** do atual. Resetar uma imagem já
  centralizada não dispara nada.
- **`RepaintBoundary`** em volta da imagem: ela é pintada numa camada própria.
  Ao mover ou mudar a opacidade, o Flutter reaproveita os pixels já pintados
  e só recompõe a camada.
- **`ListenableBuilder` + `Listenable.merge([...])`** quando um widget
  depende de mais de um notifier (ex.: botão da lanterna depende do modo,
  do estado da câmera e de a lanterna estar ligada).

### 3.4 Quando `setState` ainda é a escolha certa

`setState` não é "ruim". Na Home (Fase 1), o estado muda poucas vezes (o
usuário toca um botão) e afeta a tela quase inteira, então `setState` é a
opção mais simples. A regra prática: **use notifiers quando o valor muda
muitas vezes por segundo ou afeta só uma parte pequena da tela.**

### 3.5 Não esqueça o `dispose`

`ValueNotifier` guarda uma lista de ouvintes. Todos os notifiers criados na
`DrawingScreen` são descartados no `dispose()` dela, e o `_FlipButton`, que
adiciona um ouvinte manualmente, o remove no próprio `dispose()`. Ouvinte
esquecido = vazamento de memória e chamadas a widgets que já não existem.

---

## 4. A trava de tela

`lib/features/drawing/widgets/lock_button.dart`

- **Travar**: um toque (rápido, porque você quer travar e já começar).
- **Destravar**: **segurar 1,5 s** (um anel de progresso mostra quanto falta)
  **ou toque duplo**. Um toque acidental da mão não faz nada.
- Travada, toda a tela fica dentro de um `IgnorePointer`: nenhum toque chega
  à imagem nem aos botões. Os controles também somem, para não atrapalhar a
  visão.
- O gesto/botão **voltar** do Android também é bloqueado (`PopScope` com
  `canPop: false`), porque a lateral da mão pode disparar o gesto de voltar.

Detalhe de implementação: o "segurar" usa um `Listener` (eventos crus de
dedo descendo/subindo) e um `AnimationController` de 1,5 s. O toque duplo usa
`GestureDetector`. Cada estado registra **só o gesto que usa**: com `onTap` e
`onDoubleTap` juntos, o Flutter atrasaria o toque simples esperando para ver
se vem um segundo toque.

---

## 5. Tela sempre acesa (wakelock)

`lib/features/drawing/services/screen_wake_lock.dart`

### 5.1 O problema

Enquanto você desenha no papel, ninguém toca na tela. Para o Android isso
parece "aparelho abandonado", e ele apaga a tela depois do tempo de descanso
configurado (30 s a alguns minutos). No Modo Mesa de Luz é pior: a tela é a
fonte de luz, e ela apaga no meio do traço.

### 5.2 Como funciona no Android

O pacote `wakelock_plus` faz, no lado nativo, uma única coisa:

```kotlin
// wakelock_plus/android/.../Wakelock.kt
window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)   // enable()
window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON) // disable()
```

`FLAG_KEEP_SCREEN_ON` é uma **flag da janela** do app. Enquanto a janela
estiver visível com essa flag, o sistema não apaga a tela por inatividade.
O usuário ainda pode apagá-la pelo botão de energia, e a flag deixa de valer
quando o app sai da tela.

O nome "wakelock" engana um pouco. Existem dois mecanismos no Android:

| Mecanismo | O que mantém ligado | Permissão |
| --- | --- | --- |
| `FLAG_KEEP_SCREEN_ON` (o que usamos) | a **tela**, só com o app visível | **nenhuma** |
| `PowerManager.WakeLock` | a **CPU**, mesmo com a tela apagada e o app em segundo plano | `android.permission.WAKE_LOCK` |

### 5.3 Por que não precisa de permissão no `AndroidManifest.xml`

Uma flag de janela só afeta o **próprio app enquanto ele está na frente do
usuário**. Ela não dá ao app nenhum poder sobre o sistema quando ele não está
visível, então o Android não exige permissão. Já o `PowerManager.WakeLock`
pode manter a CPU acordada em segundo plano (e drenar a bateria sem o
usuário perceber), e por isso exige `WAKE_LOCK`.

Conferi o código do plugin: ele não declara nenhuma permissão. Ao
adicioná-lo, o `pubspec.lock` também passou a incluir `http` e
`package_info_plus`. O `wakelock_plus` só usa o `package_info_plus` no plugin
de **Linux**, e nenhum dos dois adiciona permissões ao app Android. O app
continua sem `INTERNET` no build de release.

### 5.4 Quando ligamos e desligamos

```dart
// lib/features/drawing/screens/drawing_screen.dart
initState()                    → enable()   // entrou na tela de desenho
didChangeAppLifecycleState:
  hidden                       → disable()  // minimizou / trocou de app
  resumed                      → enable()   // voltou
dispose()                      → disable()  // saiu da tela (voltou à Home)
```

- Vale nos **dois modos** (Câmera AR e Mesa de Luz): nos dois, a pessoa
  desenha sem tocar na tela.
- Só a `DrawingScreen` liga o wakelock. Na Home, a tela apaga normalmente.

### 5.5 Por que desligar no `dispose` é obrigatório

A flag fica na **janela do app**, e não na tela de desenho. O Flutter tem uma
única janela Android para o app inteiro. Se a `DrawingScreen` ligasse a flag
e não a desligasse no `dispose()`, ao voltar para a Home a tela **nunca mais
apagaria** enquanto o app estivesse aberto. Basta alguém deixar o tablet na
mesa com o app na Home: a tela fica acesa até a bateria acabar. A tela é o
componente que mais consome bateria num tablet.

O mesmo vale para `hidden`. O Android já ignora a flag com o app fora da
tela, mas desligamos explicitamente para o estado ficar previsível: "wakelock
ligado" passa a significar exatamente "tela de desenho visível".

A falha ao ligar/desligar é só registrada no console (`debugPrint`): não
manter a tela acesa é incômodo, mas não pode derrubar a tela de desenho.

Os testes de `test/drawing/drawing_screen_test.dart` (grupo "tela sempre
acesa") e `test/widget_test.dart` verificam com um wakelock falso que ele
liga ao entrar, continua ligado ao trocar de modo, desliga ao minimizar,
religa ao voltar e desliga ao sair para a Home.

---

## 6. Como testar no aparelho

1. `flutter run` com o aparelho conectado; modo avião ligado.
2. Escolha uma imagem: a tela de desenho abre sozinha.
3. **Permissão**: na primeira vez, toque em "Não permitir". O cartão "Sem
   acesso à câmera" deve aparecer; "Usar Mesa de Luz" deve funcionar.
   Depois permita em Configurações › Apps › desenha_ai › Permissões e toque
   em "Tentar novamente".
4. **Gestos**: arraste com 1 dedo; pince e gire com 2. Adicione/retire um
   dedo no meio do gesto: a imagem não deve pular.
5. **Trava**: trave, apoie a mão na tela, tente arrastar e use o gesto de
   voltar. Nada deve acontecer. Destrave segurando e também com toque duplo.
6. **Ciclo de vida**: no Modo Câmera, vá para a tela inicial do Android e
   volte. A câmera deve religar. Em Mesa de Luz, ela deve continuar desligada.
7. **Lanterna**: no Galaxy Tab A (que pode não ter flash), deve aparecer o
   aviso "Este aparelho não tem lanterna". No RedMagic, deve acender.
8. Gire o aparelho com a câmera ligada: o preview deve continuar
   preenchendo a tela sem distorcer.
9. **Tela acesa**: em Configurações › Tela, coloque o tempo de descanso em
   15 ou 30 s. Na tela de desenho (nos dois modos), espere mais que isso sem
   tocar: a tela não deve apagar. Volte para a Home e espere de novo: agora
   ela deve apagar normalmente.
