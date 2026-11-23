import 'package:material_ui/material_ui.dart';

import '../models/project_category.dart';
import '../services/category_repository.dart';
import '../services/project_repository.dart';

/// Ações de categoria usadas em MAIS de um lugar: a tela "Categorias"
/// (Etapa 5A) e o seletor de filtro (Etapa 5B). Ficam num arquivo só para as
/// duas telas terem exatamente a mesma confirmação e a mesma limpeza.

/// Pergunta se o usuário quer mesmo remover a categoria.
Future<bool> confirmRemoveCategory(
  BuildContext context,
  ProjectCategory category,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remover categoria?'),
      content: Text(
        '"${category.name}" será removida. Os desenhos com esta categoria '
        'não são apagados: eles só ficam sem categoria.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Remover'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Remove a categoria e depois limpa o vínculo dos projetos. Devolve quantos
/// desenhos ficaram sem categoria.
///
/// Ordem: primeiro a categoria, depois os projetos. Se o app for fechado
/// entre as duas etapas, alguns projetos ficam com um `categoryId` que não
/// existe mais. Isso é SEGURO: a UI trata um id desconhecido como "sem
/// categoria" (docs/06, 3.1).
Future<int> removeCategoryAndUnlink(
  ProjectCategory category, {
  required CategoryRepository categories,
  required ProjectRepository projects,
}) async {
  await categories.delete(category);
  return projects.clearCategory(category.id);
}

/// Texto da mensagem depois de remover.
String removedCategoryMessage(int clearedProjects) => switch (clearedProjects) {
      0 => 'Categoria removida.',
      1 => 'Categoria removida. 1 desenho ficou sem categoria.',
      _ =>
        'Categoria removida. $clearedProjects desenhos ficaram sem categoria.',
    };
