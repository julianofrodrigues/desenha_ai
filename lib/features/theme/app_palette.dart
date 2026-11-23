import 'package:material_ui/material_ui.dart';

/// Paleta ORIGINAL do desenha_ai (Fase 6, Etapa 6A).
///
/// Inspiração: a estética de apps de design como o Canva, com fundo claro e
/// limpo, violeta como cor principal, turquesa de destaque e cantos
/// arredondados. Os tons são PRÓPRIOS (não copiados): o violeta é mais
/// azulado e o turquesa mais esverdeado.
///
/// Todas as cores ficam aqui. Para mudar a identidade visual do app inteiro,
/// basta editar este arquivo.
abstract final class AppPalette {
  // ---- Marca (iguais nos dois modos, ajustadas onde preciso) -------------

  /// Violeta principal: botões preenchidos, seleção, foco.
  static const violet = Color(0xFF6A3DE8);

  /// Versão mais clara do violeta, para o modo escuro. Num fundo escuro, o
  /// violeta original fica escuro demais para texto e ícones.
  static const violetLight = Color(0xFFB9A2FF);

  /// Turquesa de destaque (secundária).
  static const teal = Color(0xFF12B3A8);
  static const tealLight = Color(0xFF5FE0D3);

  // ---- Modo claro ----------------------------------------------------------

  /// Fundo levemente acinzentado-lilás, e não branco puro: os cards brancos
  /// "saltam" do fundo sem precisar de sombra pesada.
  static const lightBackground = Color(0xFFF6F5FB);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceHigh = Color(0xFFECEAF4);
  static const lightOutline = Color(0xFFDCD8E8);
  static const lightText = Color(0xFF1C1A29);
  static const lightTextMuted = Color(0xFF5E5A72);

  // ---- Modo escuro ---------------------------------------------------------

  /// Grafite com um toque de azul, e não preto puro: cansa menos a vista e,
  /// em tela LCD (Galaxy Tab A), preto puro não economiza bateria.
  static const darkBackground = Color(0xFF14141C);
  static const darkSurface = Color(0xFF1D1D28);
  static const darkSurfaceHigh = Color(0xFF292937);
  static const darkOutline = Color(0xFF3A3A4C);
  static const darkText = Color(0xFFEDEBF7);
  static const darkTextMuted = Color(0xFFA9A6BD);

  // ---- Botão de tema -------------------------------------------------------

  /// Sol (modo claro) e lua (modo escuro).
  static const sun = Color(0xFFF5A524);
  static const moon = Color(0xFFC9C3FF);
}
