import 'package:material_ui/material_ui.dart';

import '../models/project_status.dart';
import '../models/status_filter.dart';
import 'project_status_style.dart';

/// Filtro de status (etapa final): "Todos" + os 4 status DIRETO na tela, sem
/// diálogo nem busca. Fica entre a barra de pesquisa e a faixa de
/// categorias.
///
/// - Tocar num status marca/desmarca; dá para marcar vários.
/// - "Todos" fica marcado quando nenhum status específico está, para o
///   usuário nunca ver todos os chips apagados sem saber o que aparece (ver
///   [StatusFilter.showsAll]).
/// - `Wrap` (e não rolagem lateral): os quatro ficam SEMPRE visíveis. Num
///   celular em pé eles ocupam duas linhas, mas nenhum fica escondido fora
///   da tela.
///
/// Rebuilds: só esta faixa escuta o [filter] (além da lista filtrada).
class StatusFilterBar extends StatelessWidget {
  const StatusFilterBar({super.key, required this.filter});

  final ValueNotifier<StatusFilter> filter;

  /// Chave do chip de cada status (para os testes).
  static Key chipKey(ProjectStatus status) =>
      ValueKey('status-filter-${status.jsonValue}');

  /// Chave do chip "Todos".
  static const allChipKey = ValueKey('status-filter-all');

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StatusFilter>(
      valueListenable: filter,
      builder: (context, current, _) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          // "Todos" vem primeiro, imediatamente à esquerda de "Não
          // iniciado". Tocar volta ao filtro vazio, que desmarca os
          // específicos. Se já estava marcado, o valor não muda e o
          // notifier nem avisa (StatusFilter tem `==`).
          _AllChip(
            selected: current.showsAll,
            onTap: () => filter.value = StatusFilter.none,
          ),
          for (final status in ProjectStatus.values)
            _StatusChip(
              status: status,
              selected: current.isSelected(status),
              onTap: () => filter.value = filter.value.toggle(status),
            ),
        ],
      ),
    );
  }
}

/// Chip "Todos": mesmo molde dos chips de status ([_ChipLook]), na cor
/// principal do tema.
///
/// Ele não tem cor própria de status, e a primária já tem um tom para o
/// claro (violeta) e outro para o escuro (violeta claro), definidos no tema.
class _AllChip extends StatelessWidget {
  const _AllChip({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ChipLook(
      key: StatusFilterBar.allChipKey,
      icon: Icons.all_inclusive,
      label: 'Todos',
      color: Theme.of(context).colorScheme.primary,
      selected: selected,
      onTap: onTap,
      tooltip: selected
          ? 'Mostrando desenhos de todos os status'
          : 'Mostrar todos os status',
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final ProjectStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ChipLook(
      key: StatusFilterBar.chipKey(status),
      icon: status.icon,
      label: status.label,
      color: status.colorIn(context),
      selected: selected,
      onTap: onTap,
      tooltip: selected
          ? 'Esconder "${status.label}"'
          : 'Mostrar "${status.label}"',
    );
  }
}

/// Visual comum a "Todos" e aos status: ícone colorido + nome.
///
/// Um widget só garante que "Todos" e os status continuem com o mesmo molde
/// se um dia o estilo mudar.
class _ChipLook extends StatelessWidget {
  const _ChipLook({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FilterChip(
      // Sem o "check" padrão: ele tomaria o lugar do ícone, que é justamente
      // o que identifica cada opção.
      showCheckmark: false,
      avatar: Icon(icon, size: 18, color: color),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      tooltip: tooltip,
      // Marcado: fundo na cor do chip, borda mais grossa e texto em negrito.
      // Três sinais juntos, para a seleção não depender só de cor.
      selectedColor: color.withValues(alpha: 0.18),
      side: BorderSide(
        color: selected ? color : colors.outlineVariant,
        width: selected ? 2 : 1,
      ),
      labelStyle: TextStyle(
        color: colors.onSurface,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}
