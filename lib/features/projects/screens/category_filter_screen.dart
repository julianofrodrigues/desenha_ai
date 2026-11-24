import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/large_button_style.dart';
import '../../../core/widgets/page_header.dart';
import '../../theme/services/theme_controller.dart';
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
  required ThemeController themeController,
}) {
  return Navigator.of(context).push<CategoryFilter>(
    MaterialPageRoute(
      // Etapa 6F: rota comum (sem `fullscreenDialog`). O "X" virou a seta
      // de voltar, então a animação lateral de navegação combina melhor do
      // que a de baixo para cima. Voltar continua descartando o rascunho.
      builder: (_) => CategoryFilterScreen(
        initial: initial,
        categoryRepository: categoryRepository,
        projectRepository: projectRepository,
        themeController: themeController,
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
/// "Aplicar". Voltar pela seta descarta as marcações (mas não desfaz
/// categorias criadas ou removidas, que já foram gravadas).
class CategoryFilterScreen extends StatefulWidget {
  const CategoryFilterScreen({
    super.key,
    required this.initial,
    required this.categoryRepository,
    required this.projectRepository,
    required this.themeController,
  });

  final CategoryFilter initial;
  final CategoryRepository categoryRepository;
  final ProjectRepository projectRepository;

  /// Botão de sol/lua no topo (Etapa 6F: presente em todas as telas).
  final ThemeController themeController;

  static const applyButtonKey = ValueKey('category-filter-apply');
  static const clearButtonKey = ValueKey('category-filter-clear');
  static const addButtonKey = ValueKey('category-filter-add');

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

  /// Editar nome e cor (Etapa 6D). Se a categoria estiver marcada no
  /// filtro, continua marcada: o id não muda.
  Future<void> _edit(ProjectCategory category) async {
    if (_busy) return;
    _searchFocusNode.unfocus();
    setState(() => _busy = true);
    final message = await editCategory(
      context,
      category: category,
      all: _categories ?? const [],
      categories: widget.categoryRepository,
    );
    if (message != null) _showMessage(message);
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
      body: SafeArea(
        // Etapa 6F: tudo numa rolagem só (slivers). Com o título mais baixo,
        // um celular deitado com o teclado aberto não teria altura para
        // cabeçalho + pesquisa + botões + lista fixos; rolando juntos, nunca
        // há overflow.
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: PageHeader(
                title: 'Filtrar por categoria',
                themeController: widget.themeController,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
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
            ),
            SliverToBoxAdapter(
              child: _FilterActions(
                canClear: _draft.isActive,
                busy: _busy,
                // Desmarca tudo no rascunho (ainda precisa de "Aplicar").
                onClear: () => setState(() => _draft = CategoryFilter.none),
                onAdd: _create,
              ),
            ),
            // Só a lista escuta o texto da pesquisa: digitar não reconstrói
            // o cabeçalho, os botões nem o "Aplicar".
            ValueListenableBuilder<TextEditingValue>(
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
                onEdit: _edit,
                onRemove: _remove,
                onCreate: _create,
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
    required this.onEdit,
    required this.onRemove,
    required this.onCreate,
  });

  final List<ProjectCategory>? categories;
  final String query;
  final CategoryFilter draft;
  final bool busy;
  final VoidCallback onToggleUncategorized;
  final ValueChanged<ProjectCategory> onToggle;
  final ValueChanged<ProjectCategory> onEdit;
  final ValueChanged<ProjectCategory> onRemove;
  final VoidCallback onCreate;

  /// Texto exibido da opção neutra, também usado para ela entrar na
  /// pesquisa ("sem" encontra "Sem categoria").
  static const uncategorizedLabel = 'Sem categoria';

  @override
  Widget build(BuildContext context) {
    final categories = this.categories;
    if (categories == null) {
      // Este widget é um SLIVER (fica dentro do `CustomScrollView`), por
      // isso o carregando vai num `SliverFillRemaining`.
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
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
    // `SliverList.list`: os itens só são construídos quando entram na tela,
    // como no `ListView` de antes.
    return SliverList.list(
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
            onEdit: () => onEdit(category),
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
              'Você ainda não criou categorias. Toque em "Adicionar '
              'categoria" para criar a primeira.',
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
        // Espaço no fim, para o último item não encostar no "Aplicar".
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Linha logo abaixo da pesquisa (Etapa 6F): "Limpar" e "Adicionar
/// categoria", os dois à DIREITA.
///
/// "Adicionar categoria" usa o mesmo molde dos botões da tela sem imagem
/// ([largeButtonStyle]); "Limpar" tem a mesma altura, mas é só texto, porque
/// é uma ação secundária. `Wrap` (e não `Row`): num celular estreito, se os
/// dois não couberem lado a lado, o segundo desce em vez de dar overflow.
class _FilterActions extends StatelessWidget {
  const _FilterActions({
    required this.canClear,
    required this.busy,
    required this.onClear,
    required this.onAdd,
  });

  final bool canClear;
  final bool busy;
  final VoidCallback onClear;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton.icon(
            key: CategoryFilterScreen.clearButtonKey,
            onPressed: canClear ? onClear : null,
            icon: const Icon(Icons.clear_all),
            label: const Text('Limpar'),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 56),
              textStyle: theme.textTheme.titleMedium,
            ),
          ),
          FilledButton.icon(
            key: CategoryFilterScreen.addButtonKey,
            onPressed: busy ? null : onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Adicionar categoria'),
            style: largeButtonStyle(theme),
          ),
        ],
      ),
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
    required this.onEdit,
    required this.onRemove,
  });

  final ProjectCategory category;
  final bool selected;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Etapa 6D: editar à esquerda do remover (mesma ordem dos cards).
          IconButton(
            tooltip: 'Editar categoria',
            onPressed: busy ? null : onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Remover categoria',
            onPressed: busy ? null : onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}
