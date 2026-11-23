import 'package:material_ui/material_ui.dart';

import '../models/project_category.dart';
import 'category_badge.dart';

/// O que o usuário preencheu no formulário de nova categoria.
typedef CategoryDraft = ({String name, int colorValue});

/// Abre o formulário. Devolve `null` se o usuário cancelar.
///
/// [existing] serve para avisar de nomes duplicados ANTES de salvar, ainda
/// com o diálogo aberto e o texto no campo.
///
/// [initialName] (Etapa 5B): o seletor de filtro oferece "Criar
/// categoria “x”" quando a pesquisa não encontra nada; o formulário já abre
/// com esse nome.
Future<CategoryDraft?> showCategoryFormDialog(
  BuildContext context, {
  required List<ProjectCategory> existing,
  String initialName = '',
}) {
  return showDialog<CategoryDraft>(
    context: context,
    builder: (_) =>
        CategoryFormDialog(existing: existing, initialName: initialName),
  );
}

/// Formulário de nova categoria: nome + cor da paleta.
///
/// `StatefulWidget` porque é dono do [TextEditingController] (descartado no
/// `dispose`) e guarda a cor escolhida e a mensagem de erro.
class CategoryFormDialog extends StatefulWidget {
  const CategoryFormDialog({
    super.key,
    required this.existing,
    this.initialName = '',
  });

  final List<ProjectCategory> existing;
  final String initialName;

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  late final _nameController =
      TextEditingController(text: widget.initialName.trim());

  /// Começa numa cor que ainda NÃO está em uso, se houver: categorias com
  /// cores diferentes são mais fáceis de distinguir no card.
  late int _colorValue = _firstUnusedColor();

  /// Erro mostrado embaixo do campo. Só aparece depois de tentar salvar, para
  /// não "brigar" com o usuário enquanto ele ainda está digitando.
  CategoryNameError? _error;

  int _firstUnusedColor() {
    final used = {for (final c in widget.existing) c.colorValue};
    return categoryPalette
        .firstWhere(
          (c) => !used.contains(c.value),
          orElse: () => categoryPalette.first,
        )
        .value;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final error = validateCategoryName(_nameController.text, widget.existing);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop<CategoryDraft>(
      (name: _nameController.text.trim(), colorValue: _colorValue),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova categoria'),
      // `SingleChildScrollView`: com o teclado aberto num celular deitado,
      // o diálogo fica baixo e a paleta precisaria rolar.
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              maxLength: ProjectCategory.maxNameLength,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              // Some o erro assim que o usuário volta a digitar.
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                labelText: 'Nome da categoria',
                errorText: _error?.message,
              ),
            ),
            const SizedBox(height: 12),
            Text('Cor', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _ColorPalette(
              selected: _colorValue,
              onSelected: (value) => setState(() => _colorValue = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Criar')),
      ],
    );
  }
}

/// Grade de bolinhas de cor. Cada uma tem 40 dp de área de toque (mínimo
/// confortável para o dedo) e uma dica com o nome da cor.
class _ColorPalette extends StatelessWidget {
  const _ColorPalette({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.onSurface;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final option in categoryPalette)
          Tooltip(
            message: 'Cor: ${option.name}',
            child: Semantics(
              button: true,
              selected: option.value == selected,
              label: 'Cor ${option.name}',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => onSelected(option.value),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  // A escolhida ganha um anel e um "check": não dependemos só
                  // da cor para mostrar a seleção (acessibilidade).
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: option.value == selected
                        ? Border.all(color: outline, width: 2)
                        : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CategoryColorDot(color: Color(option.value), size: 28),
                      if (option.value == selected)
                        const Icon(Icons.check, size: 18, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
