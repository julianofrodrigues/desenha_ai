import 'package:material_ui/material_ui.dart';

import '../models/category_filter.dart';
import '../models/project_category.dart';
import '../models/project_search.dart';
import '../services/category_repository.dart';
import '../services/project_repository.dart';
import '../widgets/category_actions.dart';
import '../widgets/category_badge.dart';
import '../widgets/category_form_dialog.dart';

/// Abre o seletor e devolve o filtro escolhido, ou `null` se o usuário
/// fechar sem aplicar (Fase 5, Etapa 5B).
///
/// Mesmo devolvendo `null`, categorias podem ter sido CRIADAS ou REMOVIDAS
/// aqui dentro (isso é gravado na hora). Por isso quem chama sempre recarrega
/// o histórico depois.
Future<CategoryFilter?> showCategoryFilterScreen(
  BuildContext context, {
  required CategoryFilter initial,
  required CategoryRepository categoryRepository,
  required ProjectRepository projectRepository,
}) {
  return Navigator.of(context).push<CategoryFilter>(
    MaterialPageRoute(
      // `fullscreenDialog`: animação de baixo para cima e botão "X" no
      // lugar da seta, deixando claro que é uma escolha que se aplica ou
      // descarta, e não uma tela de navegação.
      fullscreenDialog: true,
      builder: (_) => CategoryFilterScreen(
        initial: initial,
        categoryRepository: categoryRepository,
        projectRepository: projectRepository,
      ),
    ),
  );
}

/// Pesquisar, marcar (uma ou várias), criar e remover categorias.
///
/// Por que uma TELA (e não um `BottomSheet`)? Com o teclado aberto num
/// celular, um painel inferior fica espremido; e as mensagens (SnackBar) de
/// "categoria criada/removida" ficariam escondidas atrás dele. Uma tela
/// própria tem o seu `Scaffold` e resolve as duas coisas.
///
/// As marcações são um RASCUNHO: só valem para o histórico ao tocar em
/// "Aplicar". Fechar no "X" descarta as marcações (mas não desfaz
/// categorias criadas ou removidas, que já foram gravadas).
class CategoryFilterScreen extends StatefulWidget {
  const CategoryFilterScreen({
    super.key,
    required this.initial,
    required this.categoryRepository,
    required this.projectRepository,
  });

  final CategoryFilter initial;
  final CategoryRepository categoryRepository;
  final ProjectRepository projectRepository;

  static const applyButtonKey = ValueKey('category-filter-apply');

  @override
  State<CategoryFilterScreen> createState() => _CategoryFilterScreenState();
}

class _CategoryFilterScreenState extends State<CategoryFilterScreen> {
  // Pesquisa de categorias. Quem cria, descarta: os dois saem no `dispose`.
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  late CategoryFilter _draft = widget.initial;

  /// `null` = carregando.
  List<ProjectCategory>? _categories;

  /// Evita operações sobrepostas (ex.: toque duplo em remover).
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    List<ProjectCategory> categories;
    try {
      categories = await widget.categoryRepository.listAll();
    } catch (error) {
      debugPrint('Falha ao carregar categorias: $error');
      categories = const [];
    }
    if (!mounted) return;
    setState(() {
      _categories = categories;
      // Uma categoria marcada que não existe mais sai do rascunho.
      _draft = _draft.retainOnly(categories.map((c) => c.id));
    });
  }

  Future<void> _create() async {
    if (_busy) return;
    _searchFocusNode.unfocus();
    final draft = await showCategoryFormDialog(
      context,
      existing: _categories ?? const [],
      initialName: _searchController.text,
    );
    if (draft == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await widget.categoryRepository.create(
        name: draft.name,
        colorValue: draft.colorValue,
      );
      // Limpa a pesquisa para a categoria nova aparecer na lista.
      _searchController.clear();
      _showMessage('Categoria "${draft.name}" criada.');
    } on CategoryValidationException catch (e) {
      _showMessage(e.error.message);
    } catch (error) {
      debugPrint('Falha ao criar categoria: $error');
      _showMessage('Não foi possível criar a categoria.');
    }
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _remove(ProjectCategory category) async {
    if (_busy) return;
    _searchFocusNode.unfocus();
    if (!await confirmRemoveCategory(context, category) || !mounted) return;

    setState(() => _busy = true);
    try {
      final cleared = await removeCategoryAndUnlink(
        category,
        categories: widget.categoryRepository,
        projects: widget.projectRepository,
      );
      _showMessage(removedCategoryMessage(cleared));
    } catch (error) {
      debugPrint('Falha ao remover categoria ${category.id}: $error');
      _showMessage('Não foi possível remover a categoria.');
    }
    await _load(); // também tira a categoria removida do rascunho
    if (mounted) setState(() => _busy = false);
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filtrar por categoria'),
        actions: [
          TextButton(
            // Desmarca tudo no rascunho (ainda precisa de "Aplicar").
            onPressed: _draft.isActive
                ? () => setState(() => _draft = CategoryFilter.none)
                : null,
            child: const Text('Limpar'),
          ),
          IconButton(
            tooltip: 'Nova categoria',
            onPressed: _busy ? null : _create,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                textInputAction: TextInputAction.search,
                onTapOutside: (_) => _searchFocusNode.unfocus(),
                decoration: const InputDecoration(
                  hintText: 'Pesquisar categorias',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              // Só a lista escuta o texto da pesquisa: digitar não
              // reconstrói a barra do topo nem o botão "Aplicar".
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder: (context, value, _) => _CategoryOptions(
                  categories: _categories,
                  query: value.text,
                  draft: _draft,
                  busy: _busy,
                  onToggleUncategorized: () => setState(
                    () => _draft = _draft.toggleUncategorized(),
                  ),
                  onToggle: (c) => setState(
                    () => _draft = _draft.toggleCategory(c.id),
                  ),
                  onRemove: _remove,
                  onCreate: _create,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            // Chave estável: o texto do botão muda conforme a seleção, então
            // os testes o encontram por aqui.
            key: CategoryFilterScreen.applyButtonKey,
            onPressed: () => Navigator.of(context).pop(_draft),
            icon: const Icon(Icons.check),
            label: Text(
              _draft.isActive
                  ? 'Aplicar (${_draft.count} selecionada'
                      '${_draft.count == 1 ? '' : 's'})'
                  : 'Mostrar todos os desenhos',
            ),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
          ),
        ),
      ),
    );
  }
}

/// Lista de opções: "Sem categoria", as categorias que passam na pesquisa e,
/// se nada bater exatamente, o atalho "Criar categoria “x”".
class _CategoryOptions extends StatelessWidget {
  const _CategoryOptions({
    required this.categories,
    required this.query,
    required this.draft,
    required this.busy,
    required this.onToggleUncategorized,
    required this.onToggle,
    required this.onRemove,
    required this.onCreate,
  });

  final List<ProjectCategory>? categories;
  final String query;
  final CategoryFilter draft;
  final bool busy;
  final VoidCallback onToggleUncategorized;
  final ValueChanged<ProjectCategory> onToggle;
  final ValueChanged<ProjectCategory> onRemove;
  final VoidCallback onCreate;

  /// Texto exibido da opção neutra, também usado para ela entrar na
  /// pesquisa ("sem" encontra "Sem categoria").
  static const uncategorizedLabel = 'Sem categoria';

  @override
  Widget build(BuildContext context) {
    final categories = this.categories;
    if (categories == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final key = normalizeForSearch(query);
    final visible = key.isEmpty
        ? categories
        : [
            for (final c in categories)
              if (normalizeForSearch(c.name).contains(key)) c,
          ];
    final showUncategorized =
        key.isEmpty || normalizeForSearch(uncategorizedLabel).contains(key);
    // Atalho de criação: há texto e nenhuma categoria tem EXATAMENTE esse
    // nome (mesma regra de duplicado do formulário).
    final canCreate = key.isNotEmpty &&
        validateCategoryName(query, categories) == null;

    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (showUncategorized)
          CheckboxListTile(
            value: draft.includeUncategorized,
            onChanged: (_) => onToggleUncategorized(),
            controlAffinity: ListTileControlAffinity.leading,
            // Visual NEUTRO: ícone cinza, sem cor de categoria.
            secondary: Icon(
              Icons.label_off_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            title: const Text(uncategorizedLabel),
            subtitle: const Text('Desenhos sem categoria'),
          ),
        if (showUncategorized && visible.isNotEmpty) const Divider(height: 1),
        for (final category in visible)
          _CategoryOption(
            key: ValueKey(category.id),
            category: category,
            selected: draft.isSelected(category.id),
            busy: busy,
            onToggle: () => onToggle(category),
            onRemove: () => onRemove(category),
          ),
        if (canCreate)
          ListTile(
            enabled: !busy,
            leading: const Icon(Icons.add),
            title: Text('Criar categoria “${query.trim()}”'),
            onTap: onCreate,
          ),
        if (categories.isEmpty && !canCreate)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Você ainda não criou categorias. Toque em + para criar a '
              'primeira.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          )
        else if (visible.isEmpty && !showUncategorized && !canCreate)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Nenhuma categoria encontrada para “${query.trim()}”.',
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

/// Uma categoria na lista: caixa de marcar, cor, nome e lixeira.
class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    super.key,
    required this.category,
    required this.selected,
    required this.busy,
    required this.onToggle,
    required this.onRemove,
  });

  final ProjectCategory category;
  final bool selected;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      // A linha inteira marca/desmarca: alvo de toque grande para o dedo.
      onTap: onToggle,
      leading: Checkbox(value: selected, onChanged: (_) => onToggle()),
      title: Row(
        children: [
          CategoryColorDot(color: Color(category.colorValue)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: IconButton(
        tooltip: 'Remover categoria',
        onPressed: busy ? null : onRemove,
        icon: const Icon(Icons.delete_outline),
      ),
    );
  }
}
