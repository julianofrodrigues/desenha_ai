import 'package:material_ui/material_ui.dart';

import '../models/project_category.dart';

/// Etiqueta discreta com a COR e o NOME da categoria (Fase 5, Etapa 5A).
///
/// Legibilidade: o texto usa a cor normal do tema (que já tem bom contraste
/// no claro e no escuro). A cor da categoria aparece numa bolinha sólida e
/// num fundo bem clarinho (14% de opacidade). Pintar o TEXTO com a cor da
/// categoria ficaria ilegível com cores claras como Âmbar ou Lima.
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({super.key, required this.category});

  final ProjectCategory category;

  @override
  Widget build(BuildContext context) {
    final color = Color(category.colorValue);
    final theme = Theme.of(context);

    // Um único rótulo para o leitor de tela, em vez de "bolinha" + "texto".
    return Semantics(
      label: 'Categoria: ${category.name}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          border: Border.all(color: color.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CategoryColorDot(color: color, size: 10),
              const SizedBox(width: 6),
              // `Flexible` + ellipsis: um nome longo é cortado com "…" em vez
              // de empurrar os botões do card para fora da tela.
              Flexible(
                child: Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bolinha de cor, reaproveitada na badge, na escolha de categoria e na tela
/// de categorias.
class CategoryColorDot extends StatelessWidget {
  const CategoryColorDot({super.key, required this.color, this.size = 14});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
