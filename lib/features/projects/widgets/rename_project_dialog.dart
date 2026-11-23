import 'package:material_ui/material_ui.dart';

import '../models/drawing_project.dart';

/// Abre o diálogo de renomear e devolve o nome digitado.
///
/// - `null`: o usuário cancelou. Nada deve mudar.
/// - texto (pode ser vazio): o nome a salvar. Vazio ou só espaços significa
///   "voltar ao nome original" (a normalização fica no modelo, em
///   [DrawingProject.rename]).
Future<String?> showRenameProjectDialog(
  BuildContext context,
  DrawingProject project,
) {
  return showDialog<String>(
    context: context,
    builder: (_) => RenameProjectDialog(project: project),
  );
}

/// Diálogo simples para mudar o nome do desenho SÓ dentro do app.
///
/// É um `StatefulWidget` porque é dono de um [TextEditingController]: quem
/// cria, descarta (`dispose`). Se o controller ficasse na Home, ele
/// sobreviveria ao diálogo e guardaria o texto de uma renomeação anterior.
class RenameProjectDialog extends StatefulWidget {
  const RenameProjectDialog({super.key, required this.project});

  final DrawingProject project;

  @override
  State<RenameProjectDialog> createState() => _RenameProjectDialogState();
}

class _RenameProjectDialogState extends State<RenameProjectDialog> {
  // O campo começa com o nome que o usuário VÊ na lista, todo selecionado:
  // dá para digitar um nome novo direto ou só corrigir uma letra.
  late final TextEditingController _controller = TextEditingController(
    text: widget.project.displayName,
  )..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.project.displayName.length,
    );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_controller.text);

  /// O que aparece embaixo do campo para explicar o "deixar em branco".
  String get _helper {
    final original = widget.project.originalName.trim();
    return original.isEmpty
        ? 'Deixe em branco para usar o nome padrão.'
        : 'Deixe em branco para voltar ao nome original: $original';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Renomear desenho'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: DrawingProject.maxCustomNameLength,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: 'Nome no app',
              helperText: _helper,
              helperMaxLines: 3,
            ),
          ),
          const SizedBox(height: 8),
          // Deixa explícito o que NÃO acontece: o arquivo da galeria não é
          // renomeado. Evita o usuário procurar o nome novo na galeria.
          Text(
            'O arquivo original na galeria não é alterado.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Salvar')),
      ],
    );
  }
}
