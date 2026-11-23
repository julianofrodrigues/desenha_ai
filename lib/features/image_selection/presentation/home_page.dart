import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../drawing/screens/drawing_screen.dart';
import '../../drawing/services/screen_wake_lock.dart';
import '../../projects/models/drawing_project.dart';
import '../../projects/services/project_repository.dart';
import '../../projects/widgets/project_history_list.dart';
import '../../projects/widgets/rename_project_dialog.dart';
import '../data/local_image_source.dart';
import 'widgets/home_status_views.dart';

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

  // Barra de pesquisa (Fase 4). Ficam AQUI, e não no widget da lista,
  // porque a lista some e volta quando a Home troca de estado (ex.:
  // "Abrindo desenho…"). Aqui o texto pesquisado sobrevive a isso.
  // Quem cria, descarta: os dois são liberados no `dispose` abaixo.
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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
    // Histórico vazio = a barra de pesquisa some (tela de boas-vindas).
    // Limpamos o texto para que o próximo desenho não apareça "filtrado"
    // por uma busca que o usuário nem está vendo.
    if (projects.isEmpty) _searchController.clear();
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

  /// Renomear só dentro do app (Fase 4).
  Future<void> _rename(DrawingProject project) async {
    // Fecha o teclado da busca antes de abrir o diálogo, que tem o seu
    // próprio campo de texto.
    _searchFocusNode.unfocus();
    final name = await showRenameProjectDialog(context, project);
    if (name == null || !mounted) return; // cancelou: nada muda

    // Mesmo nome de antes: não grava nem mostra mensagem.
    final normalized = DrawingProject.normalizeCustomName(
      name,
      originalName: project.originalName,
    );
    if (normalized == project.customName) return;

    try {
      final renamed = await _repository.rename(project, name);
      if (!mounted) return;
      // Atualiza a lista NA HORA, trocando só o item renomeado. Não
      // precisamos reler o disco: a ordem não muda, porque renomear não
      // altera o "último acesso".
      setState(() {
        _projects = [
          for (final p in _projects ?? const <DrawingProject>[])
            p.id == renamed.id ? renamed : p,
        ];
      });
      _showMessage(
        renamed.customName == null
            ? 'Nome original restaurado.'
            : 'Desenho renomeado.',
      );
    } catch (error) {
      debugPrint('Falha ao renomear ${project.id}: $error');
      _showMessage('Não foi possível renomear o desenho.');
      await _loadHistory();
    }
  }

  Future<void> _confirmDelete(DrawingProject project) async {
    _searchFocusNode.unfocus();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir desenho?'),
        content: Text(
          '"${project.displayName}" e os ajustes salvos serão apagados do '
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
            _Busy(:final message) => HomeLoadingView(message: message),
            _Failed(:final message) => HomeErrorView(
                message: message,
                onRetry: _startNewDrawing,
              ),
            // Primeiro uso (ou histórico vazio): a tela de boas-vindas
            // grande, com uma única ação. A busca só aparece quando há o
            // que buscar.
            _Idle() when !hasHistory =>
              HomeWelcomeView(onPick: _startNewDrawing),
            _Idle() => ProjectHistoryList(
                projects: projects!,
                repository: _repository,
                searchController: _searchController,
                searchFocusNode: _searchFocusNode,
                onNewDrawing: _startNewDrawing,
                onOpen: _resume,
                onRename: _rename,
                onDelete: _confirmDelete,
              ),
          },
        ),
      ),
    );
  }
}
