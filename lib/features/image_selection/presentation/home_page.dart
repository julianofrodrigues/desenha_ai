import 'package:material_ui/material_ui.dart';

import '../../drawing/screens/drawing_screen.dart';
import '../../drawing/services/screen_wake_lock.dart';
import '../data/local_image_source.dart';
import 'widgets/image_preview.dart';

// ---------------------------------------------------------------------------
// Estados da tela
// ---------------------------------------------------------------------------
//
// A tela está sempre em EXATAMENTE UM destes estados. Modelar assim (em vez de
// vários booleanos como `isLoading`, `hasError`, `image != null`) impede
// combinações impossíveis, como "carregando E com erro ao mesmo tempo".
//
// `sealed` (Dart 3) avisa o compilador de que não existem outros subtipos fora
// deste arquivo. Por isso o `switch` lá embaixo é verificado: se um dia
// criarmos um estado novo e esquecermos de tratá-lo, o código não compila.

sealed class _ScreenState {
  const _ScreenState();
}

/// Nenhuma imagem escolhida ainda.
final class _Empty extends _ScreenState {
  const _Empty();
}

/// Seletor aberto ou arquivo sendo lido.
final class _Loading extends _ScreenState {
  const _Loading();
}

/// Imagem lida com sucesso.
final class _Loaded extends _ScreenState {
  const _Loaded(this.image);
  final PickedImage image;
}

/// Falha ao abrir o seletor ou ler o arquivo.
final class _Failed extends _ScreenState {
  const _Failed(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// Tela
// ---------------------------------------------------------------------------

/// Tela inicial: escolher uma imagem de referência e ver a prévia.
///
/// É um [StatefulWidget] porque o conteúdo muda conforme o usuário age
/// (vazio -> carregando -> imagem/erro). O estado mora no objeto [State],
/// que sobrevive às reconstruções do widget.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.imageSource,
    required this.cameraServiceFactory,
    required this.screenWakeLock,
  });

  final LocalImageSource imageSource;

  /// Repassada à tela de desenho, que cria e descarta a câmera.
  final CameraServiceFactory cameraServiceFactory;

  /// Repassado à tela de desenho, que liga/desliga o "tela sempre acesa".
  final ScreenWakeLock screenWakeLock;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  _ScreenState _state = const _Empty();

  bool get _isBusy => _state is _Loading;

  Future<void> _pickImage() async {
    // Proteção contra toque duplo: sem isso, dois seletores poderiam abrir
    // em sequência.
    if (_isBusy) return;

    // Guardamos o estado anterior para voltar a ele se o usuário cancelar.
    // Assim "Trocar imagem" seguido de cancelar mantém a imagem atual, que é
    // o que a pessoa espera.
    final previous = _state;
    setState(() => _state = const _Loading());

    _ScreenState next;
    try {
      final image = await widget.imageSource.pickImage();
      next = image == null ? previous : _Loaded(image);
    } catch (error) {
      // Mensagem para humanos. O detalhe técnico vai para o console de
      // depuração, onde é útil para nós, e não para a tela.
      debugPrint('Falha ao escolher imagem: $error');
      next = const _Failed(
        'Não foi possível abrir a imagem. Tente novamente ou escolha outro arquivo.',
      );
    }

    // Depois de um `await`, a tela pode ter sido fechada. Chamar `setState`
    // num State descartado gera erro, então conferimos `mounted` antes.
    if (!mounted) return;
    setState(() => _state = next);

    // Escolheu uma imagem NOVA: vai direto desenhar, que é o objetivo do
    // usuário. A prévia continua na Home para quando ele voltar.
    if (next is _Loaded && next != previous) _openDrawing(next.image);
  }

  void _openDrawing(PickedImage image) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DrawingScreen(
          image: image,
          cameraServiceFactory: widget.cameraServiceFactory,
          screenWakeLock: widget.screenWakeLock,
        ),
      ),
    );
  }

  void _clearImage() => setState(() => _state = const _Empty());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('desenha_ai'),
        actions: [
          // "Remover" só aparece quando há algo para remover, para não poluir
          // a barra com botões que não fazem nada.
          if (_state is _Loaded)
            IconButton(
              tooltip: 'Remover imagem',
              onPressed: _clearImage,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
      // `SafeArea` afasta o conteúdo de entalhes, câmeras frontais e barras do
      // sistema, que variam bastante entre o Galaxy Tab A e o RedMagic.
      body: SafeArea(
        // `AnimatedSwitcher` faz um fade curto entre os estados. A transição
        // deixa claro que algo mudou, sem atrasar o usuário.
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: switch (_state) {
            _Empty() => _EmptyView(onPick: _pickImage),
            _Loading() => const _LoadingView(),
            _Loaded(:final image) => _LoadedView(
                image: image,
                onPickAnother: _pickImage,
                onDraw: () => _openDrawing(image),
              ),
            _Failed(:final message) => _ErrorView(
                message: message,
                onRetry: _pickImage,
              ),
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Partes da tela
// ---------------------------------------------------------------------------
//
// Cada estado tem seu próprio widget pequeno. Isso deixa o `build` principal
// legível (só o switch) e permite ao Flutter reconstruir só a parte que mudou.

/// Layout centralizado com largura máxima, reaproveitado pelos estados
/// vazio/carregando/erro. Num tablet deitado, um texto esticado na largura
/// toda fica difícil de ler. 480 dp é uma largura confortável.
class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      // `SingleChildScrollView` evita "overflow" (faixa amarela e preta) em
      // celulares deitados, onde a altura é pequena.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _CenteredMessage(
      children: [
        Icon(
          Icons.draw_outlined,
          size: 96,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          'Escolha uma imagem de referência',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Use uma foto ou desenho salvo no aparelho. '
          'Nada é enviado para a internet.',
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        // Um único botão principal e grande: nesta tela só existe uma ação
        // possível, então não há o que o usuário precise decidir.
        FilledButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Escolher imagem'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(220, 56),
            textStyle: theme.textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const _CenteredMessage(
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Abrindo imagem…'),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _CenteredMessage(
      children: [
        Icon(Icons.error_outline, size: 72, color: theme.colorScheme.error),
        const SizedBox(height: 16),
        Text(
          message,
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Tentar novamente'),
        ),
      ],
    );
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({
    required this.image,
    required this.onPickAnother,
    required this.onDraw,
  });

  final PickedImage image;
  final VoidCallback onPickAnother;
  final VoidCallback onDraw;

  @override
  Widget build(BuildContext context) {
    final preview = Card(
      // `clipBehavior` corta a imagem nos cantos arredondados do cartão.
      clipBehavior: Clip.antiAlias,
      child: ImagePreview(bytes: image.bytes, onRetry: onPickAnother),
    );

    final details = _ImageDetails(
      image: image,
      onPickAnother: onPickAnother,
      onDraw: onDraw,
    );

    // Layout responsivo: com espaço de sobra na largura (tablet deitado),
    // os detalhes vão para a lateral e a imagem ganha toda a altura. Em
    // telas estreitas (celular em pé), os detalhes ficam embaixo.
    // 720 dp é um ponto de quebra comum entre "celular" e "tablet".
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: preview),
                    const SizedBox(width: 16),
                    SizedBox(width: 280, child: details),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: preview),
                    const SizedBox(height: 16),
                    details,
                  ],
                ),
        );
      },
    );
  }
}

class _ImageDetails extends StatelessWidget {
  const _ImageDetails({
    required this.image,
    required this.onPickAnother,
    required this.onDraw,
  });

  final PickedImage image;
  final VoidCallback onPickAnother;
  final VoidCallback onDraw;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          image.name,
          style: theme.textTheme.titleMedium,
          // Nomes de arquivo de câmera podem ser enormes
          // (IMG_20250101_123456789.jpg). Cortamos com "…" para não quebrar
          // o layout.
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          formatBytes(image.sizeInBytes),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        // Ação principal (preenchida) acima da secundária (contorno).
        FilledButton.icon(
          onPressed: onDraw,
          icon: const Icon(Icons.draw_outlined),
          label: const Text('Desenhar'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onPickAnother,
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Trocar imagem'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
        ),
      ],
    );
  }
}

/// Converte bytes em texto legível (ex.: `2,4 MB`).
///
/// É pública (sem `_`) só para poder ser testada isoladamente.
String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final text = unit == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  // Vírgula decimal, como se escreve no Brasil.
  return '${text.replaceAll('.', ',')} ${units[unit]}';
}
