import 'package:material_ui/material_ui.dart';

import '../models/drawing_project.dart';
import '../models/project_search.dart';
import '../services/project_repository.dart';
import 'project_history_tile.dart';
import 'project_search_field.dart';

/// Botão "Novo desenho" + seção "Continuar desenhando" com barra de pesquisa.
///
/// Saiu da `home_page.dart` na Fase 4 para a tela não passar do tamanho
/// recomendado pelo steering (~300 linhas).
///
/// Rebuilds: digitar na busca reconstrói SÓ a barra de pesquisa e a lista
/// filtrada (os dois `ValueListenableBuilder` que escutam o
/// [searchController]). O botão e o título não são reconstruídos.
class ProjectHistoryList extends StatelessWidget {
  const ProjectHistoryList({
    super.key,
    required this.projects,
    required this.repository,
    required this.searchController,
    required this.searchFocusNode,
    required this.onNewDrawing,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final List<DrawingProject> projects;
  final ProjectRepository repository;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final VoidCallback onNewDrawing;
  final ValueChanged<DrawingProject> onOpen;
  final ValueChanged<DrawingProject> onRename;
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
        // têm a miniatura decodificada (docs/04).
        child: CustomScrollView(
          // Rolar a lista fecha o teclado da busca.
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: searchController,
              builder: (context, value, _) {
                final visible = filterProjects(projects, value.text);
                if (visible.isEmpty) {
                  return SliverToBoxAdapter(
                    child: _NoResults(query: value.text.trim()),
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
                        onOpen: () => onOpen(project),
                        onRename: () => onRename(project),
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
  const _NoResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        'Nenhum desenho encontrado para “$query”.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}
