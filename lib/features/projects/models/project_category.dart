import 'package:flutter/foundation.dart';

import 'project_search.dart';

/// Uma categoria do usuário (ex.: "Animais", "Retratos"), com uma cor
/// (Fase 5, Etapa 5A).
///
/// Os projetos guardam só o [id] da categoria (`DrawingProject.categoryId`),
/// e não uma cópia do nome e da cor. Assim, um dia, editar a categoria muda
/// todos os desenhos de uma vez, e excluí-la só exige limpar o id.
@immutable
class ProjectCategory {
  const ProjectCategory({
    required this.id,
    required this.name,
    required this.colorValue,
  });

  /// Mesmo formato dos ids de projeto: só `a-z0-9`. Também é o que os
  /// projetos aceitam ao ler `categoryId` do JSON.
  static final RegExp validId = RegExp(r'^[a-z0-9]+$');

  /// Nomes de categoria são etiquetas curtas: um nome longo não cabe na
  /// badge do card sem cortar.
  static const int maxNameLength = 30;

  final String id;
  final String name;

  /// Cor em ARGB de 32 bits (ex.: `0xFFE53935`). Guardamos um `int`, e não
  /// um `Color`, para o modelo não depender de UI e o JSON ficar simples.
  final int colorValue;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'color': colorValue,
      };

  /// Lança [FormatException] se faltar o essencial (id ou nome): uma
  /// categoria sem nome não teria como ser mostrada nem escolhida.
  factory ProjectCategory.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final color = json['color'];

    if (id is! String || !validId.hasMatch(id)) {
      throw FormatException('id de categoria inválido: $id');
    }
    if (name is! String || name.trim().isEmpty) {
      throw FormatException('nome de categoria inválido: $name');
    }
    return ProjectCategory(
      id: id,
      name: name.trim(),
      // Cor inválida não descarta a categoria: usa a primeira da paleta.
      // Força a cor opaca (alpha 0xFF): uma badge transparente sumiria.
      colorValue: color is int && color >= 0 && color <= 0xFFFFFFFF
          ? color | 0xFF000000
          : categoryPalette.first.value,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProjectCategory &&
      other.id == id &&
      other.name == name &&
      other.colorValue == colorValue;

  @override
  int get hashCode => Object.hash(id, name, colorValue);

  @override
  String toString() => 'ProjectCategory($id, $name)';
}

/// Uma cor da paleta, com nome para acessibilidade (leitor de tela e dica ao
/// segurar o dedo).
@immutable
class CategoryColor {
  const CategoryColor(this.name, this.value);
  final String name;
  final int value;
}

/// Paleta fixa e pequena.
///
/// Por que não um seletor de cor livre (roda de cores)? Ele é pesado, difícil
/// de usar com o dedo e gera cores parecidas demais entre si. 12 cores bem
/// diferentes bastam para distinguir categorias de relance, e todas têm bom
/// contraste com texto claro e escuro.
const List<CategoryColor> categoryPalette = [
  CategoryColor('Vermelho', 0xFFE53935),
  CategoryColor('Rosa', 0xFFD81B60),
  CategoryColor('Roxo', 0xFF8E24AA),
  CategoryColor('Anil', 0xFF3949AB),
  CategoryColor('Azul', 0xFF1E88E5),
  CategoryColor('Ciano', 0xFF00ACC1),
  CategoryColor('Verde-azulado', 0xFF00897B),
  CategoryColor('Verde', 0xFF43A047),
  CategoryColor('Lima', 0xFF9E9D24),
  CategoryColor('Âmbar', 0xFFFFB300),
  CategoryColor('Laranja', 0xFFF4511E),
  CategoryColor('Marrom', 0xFF6D4C41),
];

/// Por que um nome de categoria foi recusado.
enum CategoryNameError {
  empty('Digite um nome para a categoria.'),
  tooLong('Use no máximo ${ProjectCategory.maxNameLength} caracteres.'),
  duplicate('Já existe uma categoria com esse nome.');

  const CategoryNameError(this.message);

  /// Mensagem amigável, mostrada embaixo do campo.
  final String message;
}

/// Valida o nome de uma categoria nova. Devolve `null` se estiver tudo certo.
///
/// Duplicados são comparados SEM maiúsculas e SEM acentos (a mesma regra da
/// busca): "Animais" e "animais " seriam a mesma etiqueta para o usuário e
/// só confundiriam na hora de escolher.
///
/// Usada pelo formulário (para mostrar o erro na hora) e pelo repositório
/// (que não confia só na UI).
CategoryNameError? validateCategoryName(
  String name,
  Iterable<ProjectCategory> existing,
) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return CategoryNameError.empty;
  if (trimmed.length > ProjectCategory.maxNameLength) {
    return CategoryNameError.tooLong;
  }
  final key = normalizeForSearch(trimmed);
  if (existing.any((c) => normalizeForSearch(c.name) == key)) {
    return CategoryNameError.duplicate;
  }
  return null;
}

/// O nome não passou em [validateCategoryName].
class CategoryValidationException implements Exception {
  const CategoryValidationException(this.error);
  final CategoryNameError error;

  @override
  String toString() => 'CategoryValidationException(${error.name})';
}
