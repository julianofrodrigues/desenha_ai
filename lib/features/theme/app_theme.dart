import 'package:material_ui/material_ui.dart';

import 'app_palette.dart';

/// Temas claro e escuro do app (Fase 6, Etapa 6A).
///
/// Os dois `ThemeData` são criados UMA vez (`static final`) e reaproveitados.
/// Ao alternar o tema, o `MaterialApp` só troca de objeto, sem recalcular
/// cores nem estilos a cada troca.
abstract final class AppTheme {
  static final ThemeData light = _build(
    ColorScheme.fromSeed(
      seedColor: AppPalette.violet,
      // `fromSeed` gera os tons intermediários (containers, variantes) com
      // contraste adequado; sobrescrevemos só as cores da nossa identidade.
      primary: AppPalette.violet,
      onPrimary: Colors.white,
      secondary: AppPalette.teal,
      onSecondary: Colors.white,
      surface: AppPalette.lightSurface,
      onSurface: AppPalette.lightText,
      onSurfaceVariant: AppPalette.lightTextMuted,
      surfaceContainerHighest: AppPalette.lightSurfaceHigh,
      outline: AppPalette.lightTextMuted,
      outlineVariant: AppPalette.lightOutline,
    ),
    background: AppPalette.lightBackground,
  );

  static final ThemeData dark = _build(
    ColorScheme.fromSeed(
      seedColor: AppPalette.violet,
      brightness: Brightness.dark,
      primary: AppPalette.violetLight,
      onPrimary: const Color(0xFF22105C),
      secondary: AppPalette.tealLight,
      onSecondary: const Color(0xFF00302C),
      surface: AppPalette.darkSurface,
      onSurface: AppPalette.darkText,
      onSurfaceVariant: AppPalette.darkTextMuted,
      surfaceContainerHighest: AppPalette.darkSurfaceHigh,
      outline: AppPalette.darkTextMuted,
      outlineVariant: AppPalette.darkOutline,
    ),
    background: AppPalette.darkBackground,
  );

  /// Estilo comum aos dois modos: só as cores mudam.
  static ThemeData _build(ColorScheme colors, {required Color background}) {
    // Cantos arredondados generosos e bordas finas no lugar de sombras: é o
    // que dá a "pegada" limpa de app de design, e sombras custam mais para
    // pintar na GPU modesta do Galaxy Tab A.
    const radius = 16.0;
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    return ThemeData(
      colorScheme: colors,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: colors.onSurface,
        // Sem a "sombra colorida" que o Material 3 aplica ao rolar: a barra
        // fica sempre lisa, como o fundo.
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colors.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: rounded.copyWith(
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: buttonShape),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: buttonShape,
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: rounded,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: buttonShape,
      ),
      dividerTheme: DividerThemeData(color: colors.outlineVariant),
    );
  }
}
