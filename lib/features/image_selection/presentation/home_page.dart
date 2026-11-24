// `dart:async` traz o `.wait` de registros de Futures (usado no
// `_loadHistory` para ler projetos e categorias em paralelo).
import 'dart:async';

// `services.dart` traz o `SystemUiOverlayStyle` (cor dos ícones da barra de
// status) e também o `Uint8List` usado nas imagens.
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../drawing/screens/drawing_screen.dart';
import '../../drawing/services/screen_wake_lock.dart';
import '../../projects/models/category_filter.dart';
import '../../projects/models/drawing_project.dart';
import '../../projects/models/project_category.dart';
import '../../projects/screens/categories_screen.dart';
import '../../projects/screens/category_filter_screen.dart';
import '../../projects/services/category_repository.dart';
import '../../projects/services/project_repository.dart';
import '../../projects/widgets/delete_project_dialog.dart';
import '../../projects/widgets/edit_project_dialog.dart';
import '../../projects/widgets/project_history_list.dart';
import '../../theme/services/theme_controller.dart';
import '../../theme/widgets/theme_toggle_button.dart';
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
    required this.categoryRepository,
    required this.cameraServiceFactory,
    required this.screenWakeLock,
    required this.themeController,
  });

  /// Alternância claro/escuro do botão de sol/lua (Fase 6).
  final ThemeController themeController;

  /// Distância do botão de sol/lua até o canto (dentro da `SafeArea`).
  ///
  /// Etapa 6C: desceu 20 dp (topo de 8 → 28 dp).
  static const themeButtonInsets = EdgeInsets.only(top: 8 + 20, right: 8);

  final LocalImageSource imageSource;

  /// Histórico de projetos salvos no aparelho.
  final ProjectRepository projectRepository;

  /// Categorias do usuário (Fase 5).
  final CategoryRepository categoryRepository;

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

  /// Categorias (Fase 5): a lista, em ordem alfabética, para o diálogo
  /// Editar, e um mapa por id, para cada card achar a sua na hora.
  List<ProjectCategory> _categories = const [];
  Map<String, ProjectCategory> _categoriesById = const {};

  bool get _isBusy => _state is _Busy;

  ProjectRepository get _repository => widget.projectRepository;

  // Barra de pesquisa (Fase 4). Ficam AQUI, e não no widget da lista,
  // porque a lista some e volta quando a Home troca de estado (ex.:
  // "Abrindo desenho…"). Aqui o texto pesquisado sobrevive a isso.
  // Quem cria, descarta: os dois são liberados no `dispose` abaixo.
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  // Filtro por categoria (Fase 5, Etapa 5B). Um `ValueNotifier`, e não um
  // campo + `setState`: marcar/desmarcar reconstrói só a faixa de
  // categorias e a lista, e não a Home inteira. Também fica aqui (e não na
  // lista) pelo mesmo motivo da busca: sobrevive às trocas de estado.
  final _categoryFilter = ValueNotifier(CategoryFilter.none);

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _categoryFilter.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    // Projetos e categorias são lidos EM PARALELO (cada um no seu arquivo),
    // e uma falha num não impede o outro: sem categorias, a lista aparece só
    // sem as badges.
    final (projects, categories) = await (
      _loadOrEmpty(_repository.listRecent, 'histórico'),
      _loadOrEmpty(widget.categoryRepository.listAll, 'categorias'),
    ).wait;
    if (!mounted) return;
    // Histórico vazio = a barra de pesquisa some (tela de boas-vindas).
    // Limpamos o texto para que o próximo desenho não apareça "filtrado"
    // por uma busca que o usuário nem está vendo.
    // O mesmo vale para o filtro de categoria. Com histórico, só tiramos do
    // filtro as categorias que não existem mais (removidas em outra tela).
    if (projects.isEmpty) {
      _searchController.clear();
      _categoryFilter.value = CategoryFilter.none;
    } else {
      _categoryFilter.value =
          _categoryFilter.value.retainOnly(categories.map((c) => c.id));
    }
    setState(() {
      _projects = projects;
      _categories = categories;
      _categoriesById = {for (final c in categories) c.id: c};
    });
  }

  /// Sem histórico (ou sem categorias) a Home continua útil: ainda dá para
  /// começar um desenho novo.
  static Future<List<T>> _loadOrEmpty<T>(
    Future<List<T>> Function() load,
    String what,
  ) async {
    try {
      return await load();
    } catch (error) {
      debugPrint('Falha ao carregar $what: $error');
      return <T>[];
    }
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

  /// Editar nome (Fase 4) e categoria (Fase 5) só dentro do app.
  Future<void> _edit(DrawingProject project) async {
    // Fecha o teclado da busca antes de abrir o diálogo, que tem o seu
    // próprio campo de texto.
    _searchFocusNode.unfocus();
    final edit = await showEditProjectDialog(
      context,
      project: project,
      categories: _categories,
    );
    if (edit == null || !mounted) return; // cancelou: nada muda

    // Compara com o que está VISÍVEL: uma categoria que não existe mais
    // conta como "sem categoria".
    final nameChanged = DrawingProject.normalizeCustomName(
          edit.name,
          originalName: project.originalName,
        ) !=
        project.customName;
    final currentCategory = project.categoryIn(_categoriesById)?.id;
    final categoryChanged = edit.categoryId != currentCategory;
    if (!nameChanged && !categoryChanged) return; // nada a gravar

    try {
      final updated = await _repository.updateDetails(
        project,
        customName: edit.name,
        categoryId: edit.categoryId,
      );
      if (!mounted) return;
      // Atualiza a lista NA HORA, trocando só o item editado. Não precisamos
      // reler o disco: a ordem não muda, porque editar não altera o "último
      // acesso".
      setState(() {
        _projects = [
          for (final p in _projects ?? const <DrawingProject>[])
            p.id == updated.id ? updated : p,
        ];
      });
      _showMessage(switch ((nameChanged, categoryChanged)) {
        (true, false) when updated.customName == null =>
          'Nome original restaurado.',
        (true, false) => 'Desenho renomeado.',
        (false, true) => 'Categoria atualizada.',
        _ => 'Desenho atualizado.',
      });
    } catch (error) {
      debugPrint('Falha ao editar ${project.id}: $error');
      _showMessage('Não foi possível salvar as alterações.');
      await _loadHistory();
    }
  }

  /// Tela de categorias (Fase 5). Ao voltar, recarrega tudo: categorias
  /// podem ter sido criadas ou removidas, e projetos podem ter perdido o
  /// vínculo.
  Future<void> _openCategories() async {
    _searchFocusNode.unfocus();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoriesScreen(
          categoryRepository: widget.categoryRepository,
          projectRepository: _repository,
        ),
      ),
    );
    await _loadHistory();
  }

  /// Seletor de categorias da faixa abaixo da busca (Etapa 5B).
  Future<void> _openCategoryPicker() async {
    _searchFocusNode.unfocus();
    final result = await showCategoryFilterScreen(
      context,
      initial: _categoryFilter.value,
      categoryRepository: widget.categoryRepository,
      projectRepository: _repository,
    );
    // `null` = fechou sem aplicar: o filtro atual continua.
    if (result != null) _categoryFilter.value = result;
    // Sempre recarrega: categorias podem ter sido criadas ou removidas lá.
    await _loadHistory();
  }

  Future<void> _confirmDelete(DrawingProject project) async {
    _searchFocusNode.unfocus();
    if (!await confirmDeleteProject(context, project)) return;

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

    // Fase 6 (Etapa 6B): SEM AppBar. Quem ajustava a cor dos ícones da barra
    // de status (relógio, bateria) era a AppBar; sem ela, fazemos aqui:
    // ícones escuros no tema claro e claros no escuro, com fundo
    // transparente para o fundo do app aparecer por trás.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBar =
        (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(statusBarColor: Colors.transparent);

    // O conteúdo de cada estado. Uma variável local (e não um método
    // `_buildX()`, que o steering desaconselha): cada estado já é um widget
    // próprio, aqui só escolhemos qual.
    final Widget content = switch (_state) {
      _Busy(:final message) => HomeLoadingView(message: message),
      _Failed(:final message) => HomeErrorView(
          message: message,
          onRetry: _startNewDrawing,
        ),
      // Primeiro uso (ou histórico vazio): a tela de boas-vindas grande. A
      // busca só aparece quando há o que buscar.
      _Idle() when !hasHistory => HomeWelcomeView(
          onPick: _startNewDrawing,
          onOpenCategories: _openCategories,
        ),
      _Idle() => ProjectHistoryList(
          projects: projects!,
          repository: _repository,
          searchController: _searchController,
          searchFocusNode: _searchFocusNode,
          onNewDrawing: _startNewDrawing,
          categoriesById: _categoriesById,
          categoryFilter: _categoryFilter,
          onOpenCategoryPicker: _openCategoryPicker,
          onOpen: _resume,
          onEdit: _edit,
          onDelete: _confirmDelete,
        ),
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: statusBar,
      child: Scaffold(
        body: Stack(
          children: [
            // `SafeArea` afasta o conteúdo de entalhes, câmeras frontais e
            // barras do sistema, que variam bastante entre o Galaxy Tab A e
            // o RedMagic.
            SafeArea(
              // `AnimatedSwitcher` faz um fade curto entre os estados. A
              // transição deixa claro que algo mudou, sem atrasar o usuário.
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: content,
              ),
            ),
            // Botão de sol/lua FLUTUANDO no canto superior direito, por
            // cima do conteúdo, igual em todos os estados (boas-vindas,
            // carregando, erro e listagem). Fica FORA do `AnimatedSwitcher`
            // para não piscar quando a Home troca de estado.
            //
            // Etapa 6C: `Positioned` (ocupa SÓ o canto, e não a tela toda
            // como o `Align` anterior). O botão não participa do layout do
            // conteúdo: descer ou aumentar o botão NUNCA empurra a marca nem
            // os botões centrais da tela inicial.
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                // Só os lados que importam para um canto superior direito.
                left: false,
                bottom: false,
                child: Padding(
                  padding: HomePage.themeButtonInsets,
                  child: ThemeToggleButton(controller: widget.themeController),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
