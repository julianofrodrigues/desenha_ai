import 'package:material_ui/material_ui.dart';

/// "Molde" dos botões grandes do app (Fase 6, Etapa 6F): 56 dp de altura e
/// texto em `titleMedium`.
///
/// Nasceu nos botões "Escolher imagem" e "Categorias" da tela sem imagem
/// (Etapa 6B) e agora também é usado no "Adicionar categoria" do seletor de
/// categorias. Ficar num lugar só garante que os dois continuem iguais.
ButtonStyle largeButtonStyle(ThemeData theme) {
  return FilledButton.styleFrom(
    minimumSize: const Size(0, _height),
    padding: _padding,
    textStyle: theme.textTheme.titleMedium,
  );
}

/// O mesmo molde de [largeButtonStyle] para um botão CONTORNADO
/// (`OutlinedButton`): mesma altura, mesmo recuo e mesma fonte.
///
/// Usado no "Limpar" do seletor de categorias. Ele faz par com o
/// "Adicionar categoria", mas é uma ação secundária: contornado (e não
/// preenchido), ele não disputa atenção com a ação principal. O canto
/// arredondado e a cor da borda vêm do tema (`outlinedButtonTheme`).
ButtonStyle largeOutlinedButtonStyle(ThemeData theme) {
  return OutlinedButton.styleFrom(
    minimumSize: const Size(0, _height),
    padding: _padding,
    textStyle: theme.textTheme.titleMedium,
  );
}

const double _height = 56;
const EdgeInsets _padding = EdgeInsets.symmetric(horizontal: 16);
