import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/page_header.dart';
import '../../theme/widgets/desenha_ai_logo.dart';
import '../../theme/widgets/theme_toggle_button.dart';
import '../models/category_filter.dart';
import '../models/drawing_project.dart';
import '../models/project_category.dart';
import '../models/project_search.dart';
import '../models/status_filter.dart';
import '../services/project_repository.dart';
import 'category_filter_bar.dart';
import 'project_history_tile.dart';
import 'project_search_field.dart';
import 'status_filter_bar.dart';

/// Botão "Novo desenho" + seção "Continuar desenhando" com barra de pesquisa.
///
/// Saiu da `home_page.dart` na Fase 4 para a tela não passar do tamanho
/// recomendado pelo steering (~300 linhas).
///
/// Rebuilds: digitar na busca ou mudar o filtro de status ou de categoria
/// reconstrói SÓ a barra/faixa que mudou e a lista filtrada. O botão "Novo
/// desenho" e o título não são reconstruídos.
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
    required this.statusFilter,
    required this.onChangeStatus,
    this.categoriesById = const {},
  });

  /// Chaves dos títulos "Status dos desenhos" e "Categorias". "Categorias"
  /// também é o texto do chip da faixa, então os testes acham o título por
  /// aqui.
  static const statusLabelKey = ValueKey('history-status-label');
  static const categoriesLabelKey = ValueKey('history-categories-label');

  /// Filtro por status (etapa final). Pertence à Home, que o descarta.
  final ValueNotifier<StatusFilter> statusFilter;

  /// Abre a escolha de status de um desenho (botão do card).
  final ValueChanged<DrawingProject> onChangeStatus;

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
            // Títulos dos dois filtros: deixam claro qual linha de chips
            // filtra o quê. São `const` e não escutam nenhum filtro, então
            // nunca são reconstruídos ao marcar um chip.
            const _FilterLabel(
              key: statusLabelKey,
              text: 'Status dos desenhos',
            ),
            // Etapa final: filtro de status ENTRE a busca e as categorias.
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverToBoxAdapter(
                child: StatusFilterBar(filter: statusFilter),
              ),
            ),
            const _FilterLabel(key: categoriesLabelKey, text: 'Categorias'),
            // Faixa de categorias logo abaixo do filtro de status (Etapa 5B).
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
            // A lista escuta a busca e os DOIS filtros: muda quando qualquer
            // um muda. `Listenable.merge` cria um objeto leve; ele é
            // recriado só quando ESTE widget é reconstruído (ex.: a Home
            // recarregou o histórico), e não a cada tecla.
            ListenableBuilder(
              listenable: Listenable.merge(
                [searchController, statusFilter, categoryFilter],
              ),
              builder: (context, _) {
                final query = searchController.text;
                // Status e categorias primeiro, depois a busca por nome (só
                // dentro dos desenhos que passaram nos filtros).
                final visible = applyHistoryFilters(
                  projects,
                  query: query,
                  statusFilter: statusFilter.value,
                  categoryFilter: categoryFilter.value,
                  categoriesById: categoriesById,
                );
                if (visible.isEmpty) {
                  final trimmed = query.trim();
                  return SliverToBoxAdapter(
                    child: _NoResults(
                      query: trimmed,
                      // O texto existe em ALGUM desenho? Se sim, quem
                      // esconde o resultado são os filtros, e a mensagem
                      // diz isso. Só roda com a lista vazia, então não pesa.
                      queryMatchesSomething: trimmed.isNotEmpty &&
                          filterProjects(projects, trimmed).isNotEmpty,
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
                        onChangeStatus: () => onChangeStatus(project),
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

/// Título discreto acima de cada linha de filtros ("Status dos desenhos",
/// "Categorias").
///
/// `labelLarge` com a cor secundária do tema: aparece, mas sem competir com
/// "Continuar desenhando" (o título da seção) nem com os chips. A cor vem do
/// tema, então se ajusta sozinha ao claro e ao escuro. O recuo de 4 dp em
/// cima separa do bloco anterior sem abrir um buraco na tela.
class _FilterLabel extends StatelessWidget {
  const _FilterLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      sliver: SliverToBoxAdapter(
        // `header`: o leitor de tela anuncia como título de seção.
        child: Semantics(
          header: true,
          child: Text(
            text,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query, required this.queryMatchesSomething});

  final String query;

  /// Algum desenho tem esse nome, mas os filtros (status/categoria) o
  /// esconderam? Muda a mensagem, para o usuário entender que é o FILTRO
  /// que esvazia a lista (e não a falta de desenhos).
  final bool queryMatchesSomething;

  String get _message {
    // Sem texto, só os filtros podem esvaziar a lista (há desenhos, senão a
    // Home mostraria a tela inicial).
    if (query.isEmpty) return 'Nenhum desenho com os filtros selecionados.';
    if (queryMatchesSomething) {
      return 'Nenhum desenho encontrado para “$query” com os filtros '
          'selecionados.';
    }
    return 'Nenhum desenho encontrado para “$query”.';
  }

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
