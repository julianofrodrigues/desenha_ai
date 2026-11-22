# 01 · Arquitetura e fundamentos de Flutter

Guia rápido para quem já programa, mas é novo em Flutter/Dart. Os exemplos
usam o código real do `desenha_ai`.

---

## 1. A ideia central: a UI é uma função do estado

No Flutter você não "manda" a tela mudar (`botao.setText(...)`). Você
descreve **como a tela deve ser para um determinado estado**, e o framework
cuida de atualizar o que mudou.

```
UI = build(estado)
```

Quando o estado muda, o Flutter chama `build` de novo e compara o resultado
com o anterior. Só o que mudou é redesenhado. Quem vem de React vai reconhecer
o modelo.

---

## 2. `Widget`

Um **widget** é uma *descrição imutável* de um pedaço da UI: um texto, um
botão, um espaçamento, um layout. Tudo é widget, inclusive coisas que em
outros frameworks seriam propriedades:

| Em outros frameworks | No Flutter |
| --- | --- |
| `padding: 16` | `Padding(padding: EdgeInsets.all(16), child: ...)` |
| `align: center` | `Center(child: ...)` |
| `visible: false` | simplesmente não incluir o widget |

Widgets são **baratos**: são só objetos de configuração, recriados a cada
`build`. Quem é "pesado" e persistente são os objetos internos que o Flutter
mantém por trás (Element e RenderObject, veja a seção 4).

Use `const` sempre que possível (`const Text('Olá')`). Um widget `const` é
criado uma vez só, em tempo de compilação, e o Flutter sabe que ele não
mudou. Isso economiza trabalho a cada reconstrução.

---

## 3. `StatelessWidget` vs `StatefulWidget`

### `StatelessWidget`: sem memória própria

Recebe dados pelo construtor e desenha. Se os dados mudarem, quem o criou
monta um novo.

```dart
// lib/app.dart
class DesenhaAiApp extends StatelessWidget {
  const DesenhaAiApp({super.key, required this.imageSource});
  final LocalImageSource imageSource;

  @override
  Widget build(BuildContext context) => MaterialApp(...);
}
```

### `StatefulWidget`: com estado que muda com o tempo

São **duas classes**:

1. O widget (`HomePage`): imutável, recriado a cada `build` do pai.
2. O `State` (`_HomePageState`): **persistente**, sobrevive às reconstruções
   e guarda os dados que mudam.

```dart
// lib/features/image_selection/presentation/home_page.dart
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.imageSource});
  final LocalImageSource imageSource;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  _ScreenState _state = const _Empty();

  Future<void> _pickImage() async {
    setState(() => _state = const _Loading()); // avisa: "mudei, redesenhe"
    // ...
  }

  @override
  Widget build(BuildContext context) { /* usa _state */ }
}
```

Regras práticas:

- **`setState`** é o único jeito de dizer ao Flutter "o estado mudou,
  chame `build` de novo". Alterar a variável sem `setState` não atualiza a
  tela.
- Dentro do `State`, acesse os parâmetros do widget com `widget.xxx`
  (ex.: `widget.imageSource`).
- Depois de um `await`, confira **`mounted`** antes de chamar `setState`: o
  usuário pode ter saído da tela enquanto você esperava.
- Ciclo de vida útil: `initState` (uma vez, ao criar), `dispose` (uma vez, ao
  destruir, para liberar controladores, câmera, streams). Vamos usar os dois
  na Fase 2 por causa da câmera.

**Qual usar?** Comece com `StatelessWidget`. Mude para `StatefulWidget` só
quando o próprio widget precisar lembrar de algo que muda (texto digitado,
item selecionado, imagem carregada, animação).

---

## 4. A árvore de widgets (e as três árvores por trás)

Widgets se aninham formando uma árvore. A tela inicial do app é, de forma
simplificada:

```
DesenhaAiApp
└─ MaterialApp
   └─ HomePage
      └─ Scaffold
         ├─ AppBar
         │  └─ Text('desenha_ai')
         └─ SafeArea
            └─ AnimatedSwitcher
               └─ _EmptyView / _LoadingView / _LoadedView / _ErrorView
```

Por baixo, o Flutter mantém três árvores paralelas:

| Árvore | O que é | Vida útil |
| --- | --- | --- |
| **Widget** | a configuração que você escreve | recriada a cada `build` |
| **Element** | a "instância" do widget naquela posição; liga widget ↔ render | persistente |
| **RenderObject** | faz layout e pinta os pixels | persistente |

Quando `build` roda de novo, o Flutter compara o widget novo com o antigo
**na mesma posição**. Se o tipo (e a `key`) forem iguais, ele só atualiza o
Element/RenderObject existente, sem recriar nada. Por isso reconstruir é
barato, e é também por isso que o `State` de um `StatefulWidget` sobrevive.

### Layout em uma frase

> **Restrições descem, tamanhos sobem, o pai posiciona.**

O pai diz ao filho "você pode ter entre X e Y de largura/altura"; o filho
escolhe um tamanho dentro disso; o pai decide onde colocá-lo. Erros comuns
de iniciante (faixa amarela e preta de *overflow*, "unbounded height") quase
sempre vêm de quebrar essa regra, por exemplo um `Column` dentro de outro
`Column` sem `Expanded`.

No `desenha_ai` usamos `LayoutBuilder` para **ler essas restrições**: em
`_LoadedView`, para decidir entre layout de tablet e de celular, e em
`ImagePreview`, para decodificar a imagem no tamanho da área visível.

---

## 5. `BuildContext`

O `BuildContext` é a **posição do widget na árvore** (tecnicamente, é o
próprio Element). Ele serve para "olhar para cima" e achar coisas que os
ancestrais fornecem:

```dart
final theme = Theme.of(context);                  // tema do MaterialApp
final dpr   = MediaQuery.devicePixelRatioOf(context); // densidade da tela
Navigator.of(context).push(...);                   // navegação (Fase 2)
```

Cuidados:

- Cada widget recebe o **seu** `context` no `build`. `Theme.of(context)` só
  enxerga o que está **acima** daquele ponto.
- Não guarde `context` em variáveis para usar depois de um `await` sem
  checar `mounted`; aquele lugar da árvore pode não existir mais.

---

## 6. `pubspec.yaml`

É o "package.json" / "build.gradle" do projeto Dart/Flutter.

```yaml
name: desenha_ai            # nome do pacote (usado em imports: package:desenha_ai/...)
version: 1.0.0+1            # versionName + versionCode do Android

environment:
  sdk: ^3.14.0              # versão do Dart exigida

dependencies:               # pacotes usados pelo app
  flutter:
    sdk: flutter
  material_ui: ^1.1.0       # widgets Material (botões, AppBar, tema)
  file_picker: ^13.4.1      # seletor de arquivos nativo (Fase 1)

dev_dependencies:           # só para desenvolvimento/testes, não vão no APK
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true   # inclui a fonte de ícones Material
  # assets: e fonts: entram aqui quando precisarmos
```

Pontos importantes:

- `^13.4.1` significa "13.4.1 ou mais novo, **sem** mudar o número
  principal" (aceita 13.9.0, recusa 14.0.0).
- As versões exatas resolvidas ficam no **`pubspec.lock`**. Ele deve ir para
  o git, para que todo mundo (e você no futuro) compile com as mesmas
  versões.
- Adicione pacotes com `flutter pub add nome_do_pacote`. O comando edita o
  `pubspec.yaml` e baixa as dependências.
- Os pacotes são baixados **uma vez** para o cache local
  (`%LOCALAPPDATA%\Pub\Cache`). Depois disso o app compila e roda sem
  internet. O app instalado no aparelho nunca precisa de rede.

> **Nota sobre `material_ui`**: nas versões mais recentes do Flutter, os
> widgets Material saíram do SDK e viraram um pacote separado. Por isso o
> import é `package:material_ui/material_ui.dart` (em tutoriais antigos você
> verá `package:flutter/material.dart`; é a mesma biblioteca).

---

## 7. Estrutura criada pelo `flutter create`

```
desenha_ai/
├─ lib/                 ← SEU código Dart. Quase tudo acontece aqui.
│  └─ main.dart         ← ponto de entrada (função main → runApp)
├─ test/                ← testes (flutter test)
├─ android/             ← projeto Android nativo (Gradle, Manifest, ícones)
│  └─ app/src/main/AndroidManifest.xml  ← permissões, nome do app, orientação
├─ pubspec.yaml         ← dependências e metadados
├─ pubspec.lock         ← versões exatas resolvidas
├─ analysis_options.yaml← regras do analisador (lints)
├─ .metadata            ← uso interno do Flutter (não editar)
├─ .dart_tool/          ← cache gerado (ignorado no git)
└─ build/               ← saída de compilação (ignorado no git)
```

Você só mexe em `android/` quando precisa de algo nativo: permissões
(câmera, na Fase 2), nome/ícone do app, versão mínima do Android.

### Estrutura que adotamos em `lib/`

Organizamos **por funcionalidade** (feature), e dentro dela por camada:

```
lib/
├─ main.dart                     ← só liga o app
├─ app.dart                      ← MaterialApp, tema, tela inicial
└─ features/
   └─ image_selection/           ← Fase 1
      ├─ data/
      │  └─ local_image_source.dart   ← fala com o pacote file_picker
      └─ presentation/
         ├─ home_page.dart            ← tela + estados
         └─ widgets/
            └─ image_preview.dart     ← prévia com loading/erro
```

Por quê:

- **Por feature**: quando a Fase 2 chegar, nasce `features/ar_drawing/` sem
  mexer no que já funciona.
- **`data/` separado de `presentation/`**: a tela não sabe que existe
  `file_picker`. Ela conhece só o contrato `LocalImageSource`. Isso permite
  trocar o pacote ou usar uma fonte falsa nos testes (veja
  `test/widget_test.dart`).
- **Sem pacote de gerenciamento de estado (ainda)**: `setState` resolve bem
  uma tela só. Quando houver estado compartilhado entre telas (Fase 2/3),
  avaliamos `ChangeNotifier` (já vem no Flutter) antes de adicionar pacotes.

---

## 8. Comandos do dia a dia

| Comando | Para quê |
| --- | --- |
| `flutter devices` | lista aparelhos conectados (ative a depuração USB no Android) |
| `flutter run` | compila e roda no aparelho em modo debug |
| `r` / `R` no terminal do `flutter run` | *hot reload* (mantém o estado) / *hot restart* (reinicia) |
| `flutter analyze` | verifica erros e boas práticas sem rodar |
| `flutter test` | roda os testes de `test/` |
| `flutter build apk --release` | gera o APK para instalar sem cabo |
| `flutter pub get` | baixa as dependências do `pubspec.yaml` |

---

## 9. Dart que aparece neste projeto

- **`final` / `const`**: `final` atribui uma vez em tempo de execução;
  `const` é constante de compilação.
- **Null safety**: `PickedImage?` pode ser `null`; `PickedImage` não. O
  compilador obriga você a tratar o `null`.
- **`async` / `await` / `Future`**: como `Promise` em JS. `pickImage()`
  devolve `Future<PickedImage?>`.
- **`sealed class` + `switch` com padrões** (Dart 3): usado em `home_page.dart`
  para os estados da tela. O compilador garante que todos os casos foram
  tratados.

  ```dart
  child: switch (_state) {
    _Empty()                => _EmptyView(...),
    _Loading()              => const _LoadingView(),
    _Loaded(:final image)   => _LoadedView(image: image, ...),
    _Failed(:final message) => _ErrorView(message: message, ...),
  },
  ```

- **`_` no início do nome**: privado ao arquivo (não existe `private` em
  Dart).
