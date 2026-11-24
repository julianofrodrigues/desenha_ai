import 'package:material_ui/material_ui.dart';

import '../../features/theme/services/theme_controller.dart';
import '../../features/theme/widgets/theme_toggle_button.dart';

/// Topo das telas internas SEM header (Fase 6, Etapas 6E e 6F).
///
/// Duas linhas, nenhuma com fundo, borda ou sombra (nada que lembre uma
/// `AppBar`):
/// 1. Seta de voltar à esquerda e o botão de sol/lua à direita, na MESMA
///    altura do botão da Home ([topInset]). Trocar de tela não faz o botão
///    "pular" de lugar.
/// 2. O título, centralizado e bem abaixo dessa linha.
///
/// Como o título fica numa linha só dele, ele usa a largura inteira e nunca
/// colide com a seta nem com o sol/lua, nem num celular de 360 dp.
///
/// Deve ficar dentro de uma `SafeArea`, que afasta tudo da barra de status.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.themeController,
  });

  final String title;

  /// Repassado ao botão de sol/lua (presente em todas as telas, Etapa 6F).
  final ThemeController themeController;

  /// Distância do topo da `SafeArea` até a linha da seta e do sol/lua. É a
  /// mesma da Home (`HomePage.themeButtonInsets`).
  static const double topInset = 28;

  /// Espaço entre a linha da seta e o título. Grande de propósito: o título
  /// fica fora da faixa onde ficaria um header clássico.
  static const double titleGap = 20;

  static const backButtonKey = ValueKey('page-header-back');
  static const titleKey = ValueKey('page-header-title');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, topInset, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Sempre a SETA (Etapa 6F), inclusive no seletor de
              // categorias, que antes mostrava "X". `maybePop` respeita um
              // `PopScope` da tela, se houver.
              IconButton(
                key: backButtonKey,
                tooltip: 'Voltar',
                iconSize: 28,
                constraints: const BoxConstraints.tightFor(
                  width: 56,
                  height: 56,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
              ),
              const Spacer(),
              ThemeToggleButton(controller: themeController),
            ],
          ),
          const SizedBox(height: titleGap),
          Text(
            title,
            key: titleKey,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
          ),
        ],
      ),
    );
  }
}
