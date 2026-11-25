import 'package:material_ui/material_ui.dart';

import '../../theme/app_palette.dart';
import '../models/project_status.dart';

/// Ícone e cor de cada status (etapa final).
///
/// Fica em `widgets/` (e não no enum) para o modelo continuar sem Flutter
/// UI. Uma `extension` permite escrever `status.icon` e
/// `status.colorFor(brightness)` como se fossem do próprio enum.
///
/// A cor nunca é a única pista: cada status tem um ícone diferente e o nome
/// escrito, para quem não distingue bem as cores.
extension ProjectStatusStyle on ProjectStatus {
  IconData get icon => switch (this) {
        ProjectStatus.notStarted => Icons.radio_button_unchecked,
        ProjectStatus.inProgress => Icons.brush_outlined,
        ProjectStatus.done => Icons.check_circle_outline,
        ProjectStatus.archived => Icons.inventory_2_outlined,
      };

  /// Cor do status no modo [brightness] (tons próprios para claro e escuro,
  /// ver [AppPalette]).
  Color colorFor(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (this) {
      ProjectStatus.notStarted => dark
          ? AppPalette.statusNotStartedDark
          : AppPalette.statusNotStartedLight,
      ProjectStatus.inProgress => dark
          ? AppPalette.statusInProgressDark
          : AppPalette.statusInProgressLight,
      ProjectStatus.done =>
        dark ? AppPalette.statusDoneDark : AppPalette.statusDoneLight,
      ProjectStatus.archived => dark
          ? AppPalette.statusArchivedDark
          : AppPalette.statusArchivedLight,
    };
  }

  /// Atalho: a cor no tema atual.
  Color colorIn(BuildContext context) =>
      colorFor(Theme.of(context).brightness);
}
