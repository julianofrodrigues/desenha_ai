import 'package:material_ui/material_ui.dart';

import '../models/project_category.dart';
import '../services/category_repository.dart';
import '../services/project_repository.dart';
import '../widgets/category_actions.dart';
import '../widgets/category_badge.dart';
import '../widgets/category_form_dialog.dart';

/// Tela para criar e remover categorias (Fase 5, Etapa 5A).
///
/// Recebe os DOIS repositórios porque remover uma categoria também limpa o
/// vínculo dos projetos que a usavam (ver [_delete]).
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({
    super.key,
    required this.categoryRepository,
    required this.projectRepository,
  });

  final CategoryRepository categoryRepository;
  final ProjectRepository projectRepository;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  /// `null` = carregando.
  List<ProjectCategory>? _categories;

  /// Evita duas operações ao mesmo tempo (ex.: toque duplo em "Excluir").
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
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
    setState(() => _categories = categories);
  }

  Future<void> _create() async {
    if (_busy) return;
    final draft = await showCategoryFormDialog(
      context,
      existing: _categories ?? const [],
    );
    if (draft == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await widget.categoryRepository.create(
        name: draft.name,
        colorValue: draft.colorValue,
      );
      _showMessage('Categoria "${draft.name}" criada.');
    } on CategoryValidationException catch (e) {
      // Raro (o formulário já valida), mas pode acontecer se a lista mudou
      // enquanto o diálogo estava aberto.
      _showMessage(e.error.message);
    } catch (error) {
      debugPrint('Falha ao criar categoria: $error');
      _showMessage('Não foi possível criar a categoria.');
    }
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  /// Remove a categoria e limpa o vínculo dos projetos (a ordem e o porquê
  /// estão em `removeCategoryAndUnlink`).
  Future<void> _delete(ProjectCategory category) async {
    if (_busy) return;
    final confirmed = await confirmRemoveCategory(context, category);
    if (!confirmed || !mounted) return;

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
    await _load();
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
    final categories = _categories;

    return Scaffold(
      appBar: AppBar(title: const Text('Categorias')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _create,
        icon: const Icon(Icons.add),
        label: const Text('Nova categoria'),
      ),
      body: SafeArea(
        child: switch (categories) {
          null => const Center(child: CircularProgressIndicator()),
          [] => const _EmptyCategories(),
          // Padrão com tipo: garante ao compilador que `list` não é nula.
          final List<ProjectCategory> list => Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                // `ListView.builder`: mesmo que a lista seja curta, é o
                // padrão preguiçoso do projeto (docs/04).
                child: ListView.builder(
                  // Espaço no fim para o botão flutuante não cobrir o último
                  // item.
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final category = list[index];
                    return Card(
                      key: ValueKey(category.id),
                      child: ListTile(
                        leading: CategoryColorDot(
                          color: Color(category.colorValue),
                          size: 24,
                        ),
                        title: Text(
                          category.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: 'Remover categoria',
                          onPressed: _busy ? null : () => _delete(category),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        },
      ),
    );
  }
}

class _EmptyCategories extends StatelessWidget {
  const _EmptyCategories();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.label_outline,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma categoria ainda',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Crie categorias para organizar seus desenhos. Depois, escolha '
              'a categoria de cada um no botão Editar.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
