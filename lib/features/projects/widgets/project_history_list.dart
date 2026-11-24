import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/page_header.dart';
import '../../theme/widgets/desenha_ai_logo.dart';
import '../../theme/widgets/theme_toggle_button.dart';
import '../models/category_filter.dart';
import '../models/drawing_project.dart';
import '../models/project_category.dart';
import '../models/project_search.dart';
import '../services/project_repository.dart';
import 'category_filter_bar.dart';
import 'project_history_tile.dart';
import 'project_search_field.dart';

/// Botão "Novo desenho" + seção "Continuar desenhando" com barra de pesquisa.
///
/// Saiu da `home_page.dart` na Fase 4 para a tela não passar do tamanho
/// recomendado pelo steering (~300 linhas).
///
/// Rebuilds: digitar na busca ou mudar o filtro de categoria reconstrói SÓ
/// a barra/faixa que mudou e a lista filtrada. O botão "Novo desenho" e o
/// título não são reconstruídos.
class ProjectHistoryList extends StatelessWidget {
  const ProjectHistoryList({
    super.key,
    required this.projects,
    required this.repository,
    required this.searchController,
    required this.searchFocusNode,
    required this.onNewDrawing,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.categoryFilter,
    required this.onOpenCategoryPicker,
    this.categoriesById = const {},
  });

  /// Filtro por categoria (Etapa 5B). Pertence à Home, que o descarta.
  final ValueNotifier<CategoryFilter> categoryFilter;

  /// Abre o seletor de categorias (pesquisar, criar, remover, marcar).
  final VoidCallback onOpenCategoryPicker;

  /// Espaço acima do título (marca "Desenha A.I").
  ///
  /// Etapa 6C: era 12 dp; desceu para 42 dp.
  /// Etapa 6F: a marca (e tudo abaixo dela) fica [gapBelowThemeButton] abaixo
  /// da BASE do botão de sol/lua: 28 (topo do botão) + 64 (altura) + 30 =
  /// 122 dp. Calculado a partir das constantes do botão: se ele mudar de
  /// tamanho ou de altura, o espaço de 30 dp continua valendo.
  static const double titleTopInset =
      PageHeader.topInset + ThemeToggleButton.size + gapBelowThemeButton;

  /// Espaço entre a base do botão de sol/lua e a marca (Etapa 6F).
  static const double gapBelowThemeButton = 30;

  /// Margem lateral do título. Etapa 6C: era 56 dp; virou 72 dp porque o
  /// botão de sol/lua ficou maior e mais baixo. Num celular de 360 dp, com
  /// 56 dp, a marca encostaria no botão.
  static const double titleSideInset = 72;

  final List<DrawingProject> projects;
  final ProjectRepository repository;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final VoidCallback onNewDrawing;
  final ValueChanged<DrawingProject> onOpen;
  final ValueChanged<DrawingProject> onEdit;
  final ValueChanged<DrawingProject> onDelete;

  /// Categorias por id (Fase 5). Um mapa, e não uma lista, porque cada card
  /// procura a sua categoria: com o mapa, isso é instantâneo.
  final Map<String, ProjectCategory> categoriesById;

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
        // têm a miniatura decodificada (docs/04).
        child: CustomScrollView(
          // Rolar a lista fecha o teclado da busca.
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            // Fase 6 (Etapa 6B): a marca "Desenha A.I" centralizada no topo.
            // Fica NA LISTA (e rola com ela) em vez de fixa no meio da tela:
            // fixa, ficaria por cima dos cards.
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(
                titleSideInset,
                titleTopInset,
                titleSideInset,
                4,
              ),
              sliver: SliverToBoxAdapter(
                child: Center(child: DesenhaAiLogo(height: 44)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Continuar desenhando',
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ),
            // Barra de pesquisa no topo da seção, logo acima dos itens.
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverToBoxAdapter(
                child: ProjectSearchField(
                  controller: searchController,
                  focusNode: searchFocusNode,
                ),
              ),
            ),
            // Faixa de categorias logo abaixo da busca (Etapa 5B).
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverToBoxAdapter(
                child: CategoryFilterBar(
                  filter: categoryFilter,
                  categoriesById: categoriesById,
                  onOpenPicker: onOpenCategoryPicker,
                ),
              ),
            ),
            // A lista escuta a busca E o filtro: muda quando qualquer um dos
            // dois muda. `Listenable.merge` cria um objeto leve; ele é
            // recriado só quando ESTE widget é reconstruído (ex.: a Home
            // recarregou o histórico), e não a cada tecla.
            ListenableBuilder(
              listenable: Listenable.merge([searchController, categoryFilter]),
              builder: (context, _) {
                final query = searchController.text;
                final filter = categoryFilter.value;
                // Categorias primeiro, depois a busca por nome (só dentro
                // das categorias marcadas).
                final visible = applyHistoryFilters(
                  projects,
                  query: query,
                  categoryFilter: filter,
                  categoriesById: categoriesById,
                );
                if (visible.isEmpty) {
                  return SliverToBoxAdapter(
                    child: _NoResults(
                      query: query.trim(),
                      filtered: filter.isActive,
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  sliver: SliverList.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final project = visible[index];
                      return ProjectHistoryTile(
                        // A key liga o widget ao PROJETO, e não à posição:
                        // ao filtrar ou excluir, os itens não "herdam" a
                        // miniatura de outro durante a reconstrução.
                        key: ValueKey(project.id),
                        project: project,
                        thumbnail: repository.thumbnailFile(project),
                        // `null` se não tem categoria OU se ela foi excluída.
                        category: project.categoryIn(categoriesById),
                        onOpen: () => onOpen(project),
                        onEdit: () => onEdit(project),
                        onDelete: () => onDelete(project),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query, required this.filtered});

  final String query;

  /// Há filtro de categoria ativo? Muda a mensagem, para o usuário entender
  /// que a lista vazia vem do filtro (e não de não ter desenhos).
  final bool filtered;

  String get _message => switch ((query.isEmpty, filtered)) {
        (true, true) => 'Nenhum desenho nas categorias selecionadas.',
        (false, true) =>
          'Nenhum desenho encontrado para “$query” nas categorias '
              'selecionadas.',
        _ => 'Nenhum desenho encontrado para “$query”.',
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        _message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}
