import 'package:material_ui/material_ui.dart';

import '../models/project_category.dart';
import 'category_badge.dart';

/// O que o usuário preencheu no formulário de categoria.
typedef CategoryDraft = ({String name, int colorValue});

/// Abre o formulário. Devolve `null` se o usuário cancelar.
///
/// - [existing]: todas as categorias, para avisar de nomes duplicados ANTES
///   de salvar, ainda com o diálogo aberto e o texto no campo.
/// - [initialName] (Etapa 5B): o seletor de filtro oferece "Criar
///   categoria “x”" quando a pesquisa não encontra nada; o formulário já
///   abre com esse nome.
/// - [editing] (Etapa 6D): a categoria que está sendo EDITADA. O formulário
///   abre com o nome e a cor dela, e o nome dela não conta como duplicado.
Future<CategoryDraft?> showCategoryFormDialog(
  BuildContext context, {
  required List<ProjectCategory> existing,
  String initialName = '',
  ProjectCategory? editing,
}) {
  return showDialog<CategoryDraft>(
    context: context,
    builder: (_) => CategoryFormDialog(
      existing: existing,
      initialName: initialName,
      editing: editing,
    ),
  );
}

/// Formulário de categoria: nome + cor da paleta. Serve para CRIAR e (desde a
/// Etapa 6D) para EDITAR.
///
/// `StatefulWidget` porque é dono do [TextEditingController] (descartado no
/// `dispose`) e guarda a cor escolhida e a mensagem de erro.
class CategoryFormDialog extends StatefulWidget {
  const CategoryFormDialog({
    super.key,
    required this.existing,
    this.initialName = '',
    this.editing,
  });

  final List<ProjectCategory> existing;
  final String initialName;
  final ProjectCategory? editing;

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  late final _nameController = TextEditingController(
    text: widget.editing?.name ?? widget.initialName.trim(),
  );

  /// Editando: a cor atual da categoria. Criando: uma cor que ainda NÃO está
  /// em uso, se houver (categorias com cores diferentes são mais fáceis de
  /// distinguir no card).
  late int _colorValue = widget.editing?.colorValue ?? _firstUnusedColor();

  /// Erro mostrado embaixo do campo. Só aparece depois de tentar salvar, para
  /// não "brigar" com o usuário enquanto ele ainda está digitando.
  CategoryNameError? _error;

  bool get _isEditing => widget.editing != null;

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
    final error = validateCategoryName(
      _nameController.text,
      widget.existing,
      // Editando: a própria categoria não é "outra com o mesmo nome".
      exceptId: widget.editing?.id,
    );
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
      title: Text(_isEditing ? 'Editar categoria' : 'Nova categoria'),
      // `SingleChildScrollView`: com o teclado aberto num celular deitado,
      // o diálogo fica baixo e a paleta precisaria rolar.
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              // Criando: o teclado já abre. Editando: muitas vezes a pessoa
              // só quer trocar a COR, e o teclado cobriria a paleta.
              autofocus: !_isEditing,
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
            CategoryColorPalette(
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
        FilledButton(
          onPressed: _save,
          child: Text(_isEditing ? 'Salvar' : 'Criar'),
        ),
      ],
    );
  }
}

/// Grade com as 30 cores da paleta (Etapa 6D).
///
/// - Cada bolinha tem 40 dp de área de toque (mínimo confortável para o
///   dedo) e uma dica com o nome da cor.
/// - Largura FIXA (5 colunas no celular, 6 no tablet). Sem isso, o
///   `AlertDialog`, que mede a largura "natural" do conteúdo, somaria as 30
///   bolinhas numa linha só e esticaria o diálogo até a borda da tela.
/// - Sem rolagem própria nem widgets pesados: 30 bolinhas simples cabem em
///   5 ou 6 linhas, e o diálogo inteiro já rola se faltar altura.
class CategoryColorPalette extends StatelessWidget {
  const CategoryColorPalette({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  static const double swatchSize = 40;
  static const double gap = 6;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.onSurface;
    final columns = MediaQuery.sizeOf(context).width >= 600 ? 6 : 5;

    return SizedBox(
      width: columns * swatchSize + (columns - 1) * gap,
      child: Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final option in categoryPalette)
            _Swatch(
              option: option,
              selected: option.value == selected,
              outline: outline,
              onTap: () => onSelected(option.value),
            ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.option,
    required this.selected,
    required this.outline,
    required this.onTap,
  });

  final CategoryColor option;
  final bool selected;
  final Color outline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(option.value);
    // "Check" escuro nas cores claras (Pêssego, Azul-céu...) e claro nas
    // escuras: branco sobre uma cor clara quase não aparece.
    final checkColor =
        color.computeLuminance() > 0.4 ? Colors.black87 : Colors.white;

    return Tooltip(
      message: 'Cor: ${option.name}',
      child: Semantics(
        button: true,
        selected: selected,
        label: 'Cor ${option.name}',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: CategoryColorPalette.swatchSize,
            height: CategoryColorPalette.swatchSize,
            alignment: Alignment.center,
            // A escolhida ganha um anel e um "check": não dependemos só da
            // cor para mostrar a seleção (acessibilidade).
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: selected ? Border.all(color: outline, width: 2) : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CategoryColorDot(color: color, size: 28),
                if (selected) Icon(Icons.check, size: 18, color: checkColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
