import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../drawing/screens/drawing_screen.dart';
import '../../drawing/services/screen_wake_lock.dart';
import '../../projects/models/drawing_project.dart';
import '../../projects/services/project_repository.dart';
import '../../projects/widgets/project_history_tile.dart';
import '../data/local_image_source.dart';

// ---------------------------------------------------------------------------
// Estados da tela
// ---------------------------------------------------------------------------
//
// A tela está sempre em EXATAMENTE UM destes estados. Modelar assim (em vez de
// vários booleanos como `isLoading`, `hasError`) impede combinações
// impossíveis, como "carregando E com erro ao mesmo tempo".
//
// `sealed` (Dart 3) avisa o compilador de que não existem outros subtipos fora
// deste arquivo. Por isso o `switch` lá embaixo é verificado: se um dia
// criarmos um estado novo e esquecermos de tratá-lo, o código não compila.

sealed class _ScreenState {
  const _ScreenState();
}

/// Pronta para o usuário escolher uma imagem ou um desenho do histórico.
final class _Idle extends _ScreenState {
  const _Idle();
}

/// Abrindo o seletor, copiando a imagem ou lendo um projeto salvo.
final class _Busy extends _ScreenState {
  const _Busy(this.message);
  final String message;
}

/// Falha ao abrir/copiar a imagem escolhida.
final class _Failed extends _ScreenState {
  const _Failed(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// Tela
// ---------------------------------------------------------------------------

/// Tela inicial: começar um desenho novo ou continuar um do histórico.
///
/// Usa `setState` (e não notifiers): o estado aqui muda poucas vezes, só
/// quando o usuário toca em algo, e afeta a tela quase inteira (docs/03, 3.4).
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.imageSource,
    required this.projectRepository,
    required this.cameraServiceFactory,
    required this.screenWakeLock,
  });

  final LocalImageSource imageSource;

  /// Histórico de projetos salvos no aparelho.
  final ProjectRepository projectRepository;

  /// Repassada à tela de desenho, que cria e descarta a câmera.
  final CameraServiceFactory cameraServiceFactory;

  /// Repassado à tela de desenho, que liga/desliga o "tela sempre acesa".
  final ScreenWakeLock screenWakeLock;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  _ScreenState _state = const _Idle();

  /// `null` = histórico ainda carregando.
  List<DrawingProject>? _projects;

  bool get _isBusy => _state is _Busy;

  ProjectRepository get _repository => widget.projectRepository;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    List<DrawingProject> projects;
    try {
      projects = await _repository.listRecent();
    } catch (error) {
      // Sem histórico a Home continua útil: ainda dá para começar um
      // desenho novo.
      debugPrint('Falha ao carregar o histórico: $error');
      projects = const [];
    }
    if (!mounted) return;
    setState(() => _projects = projects);
  }

  /// Novo desenho: escolher imagem → copiar para o app → abrir.
  Future<void> _startNewDrawing() async {
    // Proteção contra toque duplo: sem isso, dois seletores poderiam abrir.
    if (_isBusy) return;
    setState(() => _state = const _Busy('Abrindo imagem…'));

    final PickedImage? image;
    try {
      image = await widget.imageSource.pickImage();
    } catch (error) {
      debugPrint('Falha ao escolher imagem: $error');
      _setStateIfMounted(const _Failed(
        'Não foi possível abrir a imagem. Tente novamente ou escolha outro '
        'arquivo.',
      ));
      return;
    }

    // Cancelar o seletor não é erro: só volta ao normal.
    if (image == null) {
      _setStateIfMounted(const _Idle());
      return;
    }

    _setStateIfMounted(const _Busy('Preparando desenho…'));
    final DrawingProject project;
    try {
      // A cópia acontece ANTES de abrir a tela: se o arquivo original for
      // apagado da galeria depois, o projeto continua funcionando.
      project = await _repository.create(
        originalName: image.name,
        imageBytes: image.bytes,
      );
    } catch (error) {
      debugPrint('Falha ao criar projeto: $error');
      _setStateIfMounted(const _Failed(
        'Não foi possível salvar a imagem no aparelho. Verifique se há '
        'espaço livre e tente novamente.',
      ));
      return;
    }

    _setStateIfMounted(const _Idle());
    await _openDrawing(project, image.bytes);
  }

  /// Continuar um desenho do histórico.
  Future<void> _resume(DrawingProject project) async {
    if (_isBusy) return;
    setState(() => _state = const _Busy('Abrindo desenho…'));

    final Uint8List bytes;
    final DrawingProject opened;
    try {
      bytes = await _repository.readImage(project);
      // Gravar ao abrir atualiza o "último acesso", que ordena o histórico.
      opened = await _repository.save(project);
    } catch (error) {
      debugPrint('Falha ao abrir projeto ${project.id}: $error');
      _setStateIfMounted(const _Idle());
      _showMessage(
        'Não foi possível abrir este desenho. Os arquivos dele podem ter '
        'sido apagados.',
      );
      return;
    }

    _setStateIfMounted(const _Idle());
    await _openDrawing(opened, bytes);
  }

  Future<void> _openDrawing(DrawingProject project, Uint8List bytes) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DrawingScreen(
          project: project,
          imageBytes: bytes,
          projectRepository: _repository,
          cameraServiceFactory: widget.cameraServiceFactory,
          screenWakeLock: widget.screenWakeLock,
        ),
      ),
    );
    // Voltou da tela de desenho: o projeto mudou de posição/ajustes.
    await _loadHistory();
  }

  Future<void> _confirmDelete(DrawingProject project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir desenho?'),
        content: Text(
          '"${project.originalName}" e os ajustes salvos serão apagados do '
          'app. A imagem original na galeria não é afetada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _repository.delete(project);
      _showMessage('Desenho excluído.');
    } catch (error) {
      debugPrint('Falha ao excluir ${project.id}: $error');
      _showMessage('Não foi possível excluir o desenho.');
    }
    await _loadHistory();
  }

  // Depois de um `await`, a tela pode ter sido fechada. Chamar `setState`
  // num State descartado gera erro, então conferimos `mounted` antes.
  void _setStateIfMounted(_ScreenState state) {
    if (mounted) setState(() => _state = state);
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final projects = _projects;
    final hasHistory = projects != null && projects.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('desenha_ai')),
      // `SafeArea` afasta o conteúdo de entalhes, câmeras frontais e barras do
      // sistema, que variam bastante entre o Galaxy Tab A e o RedMagic.
      body: SafeArea(
        // `AnimatedSwitcher` faz um fade curto entre os estados. A transição
        // deixa claro que algo mudou, sem atrasar o usuário.
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: switch (_state) {
            _Busy(:final message) => _LoadingView(message: message),
            _Failed(:final message) => _ErrorView(
                message: message,
                onRetry: _startNewDrawing,
              ),
            // Primeiro uso (ou histórico vazio): a tela de boas-vindas
            // grande, com uma única ação.
            _Idle() when !hasHistory => _EmptyView(onPick: _startNewDrawing),
            _Idle() => _HistoryView(
                projects: projects!,
                repository: _repository,
                onNewDrawing: _startNewDrawing,
                onOpen: _resume,
                onDelete: _confirmDelete,
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
  const _LoadingView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _CenteredMessage(
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(message),
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

/// Botão de novo desenho + lista "Continuar desenhando".
class _HistoryView extends StatelessWidget {
  const _HistoryView({
    required this.projects,
    required this.repository,
    required this.onNewDrawing,
    required this.onOpen,
    required this.onDelete,
  });

  final List<DrawingProject> projects;
  final ProjectRepository repository;
  final VoidCallback onNewDrawing;
  final ValueChanged<DrawingProject> onOpen;
  final ValueChanged<DrawingProject> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        // Em tablet deitado, uma lista da largura toda fica esticada demais.
        constraints: const BoxConstraints(maxWidth: 720),
        // `CustomScrollView` + `SliverList.builder`: a lista é PREGUIÇOSA.
        // Só os itens visíveis (e uma pequena margem) são construídos e
        // têm a miniatura decodificada. Com 50 projetos, ainda são uns 8
        // na memória de cada vez (docs/04).
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverToBoxAdapter(
                child: FilledButton.icon(
                  onPressed: onNewDrawing,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Novo desenho'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    textStyle: theme.textTheme.titleMedium,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Continuar desenhando',
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              sliver: SliverList.builder(
                itemCount: projects.length,
                itemBuilder: (context, index) {
                  final project = projects[index];
                  return ProjectHistoryTile(
                    // A key liga o widget ao PROJETO, e não à posição na
                    // lista: ao excluir um item, os outros não "herdam" a
                    // miniatura errada durante a reconstrução.
                    key: ValueKey(project.id),
                    project: project,
                    thumbnail: repository.thumbnailFile(project),
                    onOpen: () => onOpen(project),
                    onDelete: () => onDelete(project),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
