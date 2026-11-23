import 'package:material_ui/material_ui.dart';

import '../models/drawing_project.dart';

/// Pergunta se o usuário quer mesmo excluir o desenho. Devolve `true` só se
/// ele confirmar.
///
/// Saiu da `home_page.dart` na Fase 5, para a tela não crescer além do
/// tamanho recomendado pelo steering. O texto e o comportamento são os
/// mesmos da Fase 3.
Future<bool> confirmDeleteProject(
  BuildContext context,
  DrawingProject project,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Excluir desenho?'),
      content: Text(
        '"${project.displayName}" e os ajustes salvos serão apagados do '
        'app. A imagem original na galeria não é afetada.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Excluir'),
        ),
      ],
    ),
  );
  return confirmed == true;
}
