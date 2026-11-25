import 'package:material_ui/material_ui.dart';

import '../models/project_status.dart';
import 'project_status_style.dart';

/// Etiqueta do status no card (etapa final): ícone, cor e nome.
///
/// Mesmo molde da `CategoryBadge` (fundo de 14%, borda de 60%, cantos
/// redondos), para as duas etiquetas formarem uma linha só. O TEXTO usa a
/// cor normal do tema, que tem bom contraste nos dois modos; a cor do
/// status vai no ícone e na borda.
class ProjectStatusBadge extends StatelessWidget {
  const ProjectStatusBadge({super.key, required this.status});

  final ProjectStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status.colorIn(context);
    final theme = Theme.of(context);

    // Um único rótulo para o leitor de tela, em vez de "ícone" + "texto".
    return Semantics(
      label: 'Status: ${status.label}',
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
              Icon(status.icon, size: 14, color: color),
              const SizedBox(width: 4),
              // `Flexible` + "…": num celular estreito, com três botões no
              // card, o nome é cortado em vez de estourar a largura.
              Flexible(
                child: Text(
                  status.label,
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
