import 'package:flutter/foundation.dart';

import 'drawing_project.dart';

/// Quais categorias estão filtrando o histórico (Fase 5, Etapa 5B).
///
/// - Nada marcado ([isActive] falso): mostra TODOS os desenhos, exatamente
///   como nas Fases 3 e 4.
/// - Categorias marcadas: só os desenhos dessas categorias.
/// - "Sem categoria" marcada: só os desenhos sem categoria (inclui os que
///   apontam para uma categoria que foi apagada).
/// - Categorias + "Sem categoria": a UNIÃO dos dois conjuntos.
///
/// Imutável, com `==`: o `ValueNotifier` da Home só avisa a lista quando o
/// filtro muda de verdade (ver steering, seção 3).
@immutable
class CategoryFilter {
  const CategoryFilter({
    this.categoryIds = const {},
    this.includeUncategorized = false,
  });

  /// Nenhum filtro.
  static const none = CategoryFilter();

  /// Ids das categorias marcadas.
  final Set<String> categoryIds;

  /// "Sem categoria" marcada.
  final bool includeUncategorized;

  bool get isActive => categoryIds.isNotEmpty || includeUncategorized;

  /// Quantos itens estão marcados (para o contador do botão).
  int get count => categoryIds.length + (includeUncategorized ? 1 : 0);

  bool isSelected(String categoryId) => categoryIds.contains(categoryId);

  CategoryFilter toggleCategory(String categoryId) {
    final ids = {...categoryIds};
    if (!ids.remove(categoryId)) ids.add(categoryId);
    return CategoryFilter(
      categoryIds: Set.unmodifiable(ids),
      includeUncategorized: includeUncategorized,
    );
  }

  CategoryFilter toggleUncategorized() => CategoryFilter(
        categoryIds: categoryIds,
        includeUncategorized: !includeUncategorized,
      );

  /// Tira do filtro as categorias que não existem mais (ex.: removidas na
  /// tela de categorias). Sem isso, um filtro só com categorias apagadas
  /// esconderia todos os desenhos sem o usuário entender por quê.
  CategoryFilter retainOnly(Iterable<String> existingIds) {
    final existing = existingIds.toSet();
    final kept = categoryIds.where(existing.contains).toSet();
    if (kept.length == categoryIds.length) return this;
    return CategoryFilter(
      categoryIds: Set.unmodifiable(kept),
      includeUncategorized: includeUncategorized,
    );
  }

  /// O projeto passa no filtro?
  ///
  /// Usa a categoria RESOLVIDA (`categoryIn`): um id de categoria apagada
  /// conta como "sem categoria", a mesma regra da badge (Etapa 5A).
  bool matches(DrawingProject project, Map<String, Object?> categoriesById) {
    if (!isActive) return true;
    final category = project.categoryIn(categoriesById);
    if (category == null) return includeUncategorized;
    return categoryIds.contains(project.categoryId);
  }

  @override
  bool operator ==(Object other) =>
      other is CategoryFilter &&
      other.includeUncategorized == includeUncategorized &&
      setEquals(other.categoryIds, categoryIds);

  @override
  int get hashCode => Object.hash(
        includeUncategorized,
        // Soma dos hashes: independe da ordem dos itens no conjunto.
        categoryIds.fold<int>(0, (sum, id) => sum + id.hashCode),
      );

  @override
  String toString() =>
      'CategoryFilter($categoryIds, semCategoria: $includeUncategorized)';
}
