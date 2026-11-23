import 'package:material_ui/material_ui.dart';

import '../models/category_filter.dart';
import '../models/project_category.dart';
import 'category_badge.dart';

/// Faixa compacta logo abaixo da barra de pesquisa (Fase 5, Etapa 5B).
///
/// ```
/// [ Sem categoria ] [● Animais ×] [● Retratos ×] ...   [Categorias (2)]
/// └─────────── rola para o lado ───────────┘          └─ sempre visível
/// ```
///
/// - "Sem categoria" está SEMPRE presente, com visual neutro (sem cor):
///   tocar marca/desmarca o filtro de desenhos sem categoria.
/// - As categorias marcadas aparecem como etiquetas coloridas com "×"
///   para tirar do filtro sem abrir o seletor.
/// - O botão da direita abre o seletor para pesquisar, criar, remover e
///   marcar categorias.
///
/// Rebuilds: só esta faixa escuta o [filter]. Uma linha só, com rolagem
/// horizontal: muitas categorias marcadas não empurram a lista para baixo.
class CategoryFilterBar extends StatelessWidget {
  const CategoryFilterBar({
    super.key,
    required this.filter,
    required this.categoriesById,
    required this.onOpenPicker,
  });

  final ValueNotifier<CategoryFilter> filter;
  final Map<String, ProjectCategory> categoriesById;
  final VoidCallback onOpenPicker;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CategoryFilter>(
      valueListenable: filter,
      builder: (context, current, _) {
        // Na ordem alfabética das categorias (a mesma do seletor), e não na
        // ordem em que foram marcadas: a faixa não "embaralha" a cada toque.
        final selected = [
          for (final category in categoriesById.values)
            if (current.isSelected(category.id)) category,
        ];
        return Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _UncategorizedChip(
                      selected: current.includeUncategorized,
                      onTap: () =>
                          filter.value = filter.value.toggleUncategorized(),
                    ),
                    for (final category in selected)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _SelectedCategoryChip(
                          category: category,
                          onRemove: () => filter.value =
                              filter.value.toggleCategory(category.id),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            ActionChip(
              tooltip: 'Pesquisar e criar categorias',
              avatar: const Icon(Icons.manage_search, size: 18),
              label: Text(
                current.isActive
                    ? 'Categorias (${current.count})'
                    : 'Categorias',
              ),
              onPressed: onOpenPicker,
            ),
          ],
        );
      },
    );
  }
}

/// Etiqueta neutra "Sem categoria": cinza, sem cor vibrante.
///
/// Desmarcada é só um contorno discreto; marcada ganha um fundo cinza
/// claro e o "check", para a seleção não depender só de cor.
class _UncategorizedChip extends StatelessWidget {
  const _UncategorizedChip({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FilterChip(
      label: const Text('Sem categoria'),
      selected: selected,
      onSelected: (_) => onTap(),
      tooltip: selected
          ? 'Parar de filtrar desenhos sem categoria'
          : 'Mostrar só desenhos sem categoria',
      avatar: selected
          ? null
          : Icon(
              Icons.label_off_outlined,
              size: 18,
              color: colors.onSurfaceVariant,
            ),
      // Cores do próprio tema (superfície/contorno), e nunca a cor primária:
      // é isso que deixa a etiqueta "incolor".
      selectedColor: colors.surfaceContainerHighest,
      checkmarkColor: colors.onSurfaceVariant,
      side: BorderSide(color: colors.outlineVariant),
      labelStyle: TextStyle(color: colors.onSurfaceVariant),
    );
  }
}

/// Categoria marcada no filtro, com a sua cor e um "×" para desmarcar.
class _SelectedCategoryChip extends StatelessWidget {
  const _SelectedCategoryChip({required this.category, required this.onRemove});

  final ProjectCategory category;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final color = Color(category.colorValue);
    return InputChip(
      avatar: CategoryColorDot(color: color, size: 12),
      label: Text(category.name),
      // Mesmo estilo discreto da badge do card (Etapa 5A).
      backgroundColor: color.withValues(alpha: 0.14),
      side: BorderSide(color: color.withValues(alpha: 0.6)),
      onDeleted: onRemove,
      deleteButtonTooltipMessage: 'Tirar "${category.name}" do filtro',
    );
  }
}
