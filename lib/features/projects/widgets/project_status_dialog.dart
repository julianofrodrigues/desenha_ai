import 'package:material_ui/material_ui.dart';

import '../models/project_status.dart';
import 'project_status_style.dart';

/// Abre a escolha de status e devolve o escolhido, ou `null` se o usuário
/// cancelar (etapa final).
///
/// Um toque numa opção já ESCOLHE e fecha: não há botão "Salvar". São só
/// quatro opções, e trocar de novo é igualmente rápido.
Future<ProjectStatus?> showProjectStatusDialog(
  BuildContext context, {
  required ProjectStatus current,
}) {
  return showDialog<ProjectStatus>(
    context: context,
    builder: (_) => ProjectStatusDialog(current: current),
  );
}

/// Lista dos 4 status, com ícone, cor e nome. O atual aparece marcado.
class ProjectStatusDialog extends StatelessWidget {
  const ProjectStatusDialog({super.key, required this.current});

  final ProjectStatus current;

  /// Chave de cada opção (para os testes tocarem nela sem depender do
  /// texto, que também aparece na badge do card por trás do diálogo).
  static Key optionKey(ProjectStatus status) =>
      ValueKey('status-option-${status.jsonValue}');

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('Status do desenho'),
      children: [
        for (final status in ProjectStatus.values)
          _StatusOption(
            status: status,
            selected: status == current,
            onTap: () => Navigator.of(context).pop(status),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusOption extends StatelessWidget {
  const _StatusOption({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final ProjectStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = status.colorIn(context);
    return ListTile(
      key: ProjectStatusDialog.optionKey(status),
      onTap: onTap,
      selected: selected,
      // O ícone e o círculo de fundo usam a cor do status; o texto, a do
      // tema (legível nos dois modos).
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.16),
        child: Icon(status.icon, color: color),
      ),
      title: Text(
        status.label,
        style: selected ? const TextStyle(fontWeight: FontWeight.w700) : null,
      ),
      // O status atual também tem um "check", para não depender só da cor
      // de seleção do ListTile.
      trailing: selected ? const Icon(Icons.check) : null,
    );
  }
}

/// Mensagem depois de trocar o status.
///
/// Se o status novo não está marcado no filtro, o card some da lista na
/// hora. A mensagem explica por quê, para não parecer que o desenho foi
/// apagado.
String statusChangedMessage(ProjectStatus status, {required bool hidden}) {
  final base = 'Status alterado para "${status.label}".';
  return hidden
      ? '$base O desenho saiu da lista porque esse status não está marcado '
          'no filtro.'
      : base;
}
