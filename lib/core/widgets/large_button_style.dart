import 'package:material_ui/material_ui.dart';

/// "Molde" dos botões grandes do app (Fase 6, Etapa 6F): 56 dp de altura e
/// texto em `titleMedium`.
///
/// Nasceu nos botões "Escolher imagem" e "Categorias" da tela sem imagem
/// (Etapa 6B) e agora também é usado no "Adicionar categoria" do seletor de
/// categorias. Ficar num lugar só garante que os dois continuem iguais.
ButtonStyle largeButtonStyle(ThemeData theme) {
  return FilledButton.styleFrom(
    minimumSize: const Size(0, 56),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    textStyle: theme.textTheme.titleMedium,
  );
}
