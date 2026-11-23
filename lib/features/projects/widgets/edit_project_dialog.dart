import 'package:material_ui/material_ui.dart';

import '../models/drawing_project.dart';
import '../models/project_category.dart';
import 'category_badge.dart';

/// O que o usuário escolheu no diálogo Editar.
///
/// - [name]: texto digitado (pode ser vazio = voltar ao nome original).
/// - [categoryId]: categoria escolhida, ou `null` = "Sem categoria".
typedef ProjectEdit = ({String name, String? categoryId});

/// Abre o diálogo Editar. Devolve `null` se o usuário cancelar.
///
/// Na Fase 4 este diálogo só renomeava (`RenameProjectDialog`). Na Fase 5
/// ele ganhou a escolha de categoria e passou a se chamar "Editar".
Future<ProjectEdit?> showEditProjectDialog(
  BuildContext context, {
  required DrawingProject project,
  required List<ProjectCategory> categories,
}) {
  return showDialog<ProjectEdit>(
    context: context,
    builder: (_) =>
        EditProjectDialog(project: project, categories: categories),
  );
}

/// Diálogo para mudar o nome (SÓ dentro do app) e a categoria do desenho.
///
/// É um `StatefulWidget` porque é dono de um [TextEditingController]: quem
/// cria, descarta (`dispose`). Também guarda a categoria selecionada.
class EditProjectDialog extends StatefulWidget {
  const EditProjectDialog({
    super.key,
    required this.project,
    required this.categories,
  });

  final DrawingProject project;
  final List<ProjectCategory> categories;

  @override
  State<EditProjectDialog> createState() => _EditProjectDialogState();
}

class _EditProjectDialogState extends State<EditProjectDialog> {
  // O campo começa com o nome que o usuário VÊ na lista, todo selecionado:
  // dá para digitar um nome novo direto ou só corrigir uma letra.
  late final TextEditingController _controller = TextEditingController(
    text: widget.project.displayName,
  )..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.project.displayName.length,
    );

  /// Começa na categoria atual, mas SÓ se ela ainda existir. Um id que não
  /// está na lista (categoria excluída) começa como "Sem categoria".
  late String? _categoryId = widget.categories
          .any((c) => c.id == widget.project.categoryId)
      ? widget.project.categoryId
      : null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop<ProjectEdit>(
        (name: _controller.text, categoryId: _categoryId),
      );

  /// O que aparece embaixo do campo para explicar o "deixar em branco".
  String get _helper {
    final original = widget.project.originalName.trim();
    return original.isEmpty
        ? 'Deixe em branco para usar o nome padrão.'
        : 'Deixe em branco para voltar ao nome original: $original';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Editar desenho'),
      // Com várias categorias e o teclado aberto, o conteúdo pode não caber.
      content: SingleChildScrollView(
        child: Column(
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
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text('Categoria', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _CategoryChoices(
              categories: widget.categories,
              selectedId: _categoryId,
              onSelected: (id) => setState(() => _categoryId = id),
            ),
            if (widget.categories.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Você ainda não criou categorias. Use o botão de etiqueta no '
                'topo da tela inicial.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
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

/// Chips de escolha única: "Sem categoria" + uma por categoria.
///
/// Por que chips, e não uma lista suspensa (dropdown)? Com poucas
/// categorias, todas ficam visíveis de uma vez, com a cor ao lado do nome, e
/// escolher é um único toque.
class _CategoryChoices extends StatelessWidget {
  const _CategoryChoices({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<ProjectCategory> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        ChoiceChip(
          label: const Text('Sem categoria'),
          selected: selectedId == null,
          onSelected: (_) => onSelected(null),
        ),
        for (final category in categories)
          ChoiceChip(
            avatar: CategoryColorDot(color: Color(category.colorValue)),
            label: Text(category.name),
            selected: selectedId == category.id,
            // O ícone de "check" padrão substituiria a bolinha de cor; a
            // borda/fundo do chip selecionado já mostram a seleção.
            showCheckmark: false,
            onSelected: (_) => onSelected(category.id),
          ),
      ],
    );
  }
}
