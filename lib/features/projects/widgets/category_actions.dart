import 'package:material_ui/material_ui.dart';

import '../models/project_category.dart';
import '../services/category_repository.dart';
import '../services/project_repository.dart';
import 'category_form_dialog.dart';

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

/// Fluxo completo de EDITAR uma categoria (Etapa 6D): abre o formulário com
/// o nome e a cor atuais e grava a alteração.
///
/// Devolve a mensagem para mostrar ao usuário, ou `null` se ele cancelou ou
/// não mudou nada. Usado pela tela "Categorias" e pelo seletor da faixa, para
/// as duas terem exatamente o mesmo comportamento.
///
/// Os desenhos guardam só o ID da categoria (docs/06, 1.3). Por isso basta
/// gravar a categoria: quando a Home recarrega, todos os cards vinculados já
/// mostram o nome e a cor novos, sem reescrever nenhum projeto.
Future<String?> editCategory(
  BuildContext context, {
  required ProjectCategory category,
  required List<ProjectCategory> all,
  required CategoryRepository categories,
}) async {
  final draft = await showCategoryFormDialog(
    context,
    existing: all,
    editing: category,
  );
  if (draft == null) return null; // cancelou
  if (draft.name == category.name && draft.colorValue == category.colorValue) {
    return null; // nada mudou: não grava
  }
  try {
    final updated = await categories.update(
      category,
      name: draft.name,
      colorValue: draft.colorValue,
    );
    return 'Categoria "${updated.name}" atualizada.';
  } on CategoryValidationException catch (e) {
    // Raro (o formulário já valida), mas a lista pode ter mudado enquanto o
    // diálogo estava aberto.
    return e.error.message;
  } on CategoryNotFoundException {
    return 'Esta categoria não existe mais.';
  } catch (error) {
    debugPrint('Falha ao editar categoria ${category.id}: $error');
    return 'Não foi possível salvar a categoria.';
  }
}

/// Texto da mensagem depois de remover.
String removedCategoryMessage(int clearedProjects) => switch (clearedProjects) {
      0 => 'Categoria removida.',
      1 => 'Categoria removida. 1 desenho ficou sem categoria.',
      _ =>
        'Categoria removida. $clearedProjects desenhos ficaram sem categoria.',
    };
