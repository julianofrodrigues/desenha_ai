// Telas de estado da Home: boas-vindas, carregando e erro.
//
// Saíram da `home_page.dart` na Fase 4, para a tela não passar do tamanho
// recomendado pelo steering (~300 linhas). Cada estado tem seu próprio
// widget pequeno: o `build` da Home fica só com o `switch`, e o Flutter
// reconstrói só a parte que mudou.
import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/large_button_style.dart';
import '../../../theme/widgets/desenha_ai_logo.dart';

/// Layout centralizado com largura máxima, reaproveitado pelos estados
/// vazio/carregando/erro. Num tablet deitado, um texto esticado na largura
/// toda fica difícil de ler. 480 dp é uma largura confortável.
class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      // `SingleChildScrollView` evita "overflow" (faixa amarela e preta) em
      // celulares deitados, onde a altura é pequena.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Boas-vindas: aparece quando ainda não há nenhum desenho no histórico.
///
/// Fase 6 (Etapa 6B): a marca "Desenha A.I" desenhada fica no centro, e os
/// botões "Escolher imagem" e "Categorias" ficam LADO A LADO, no mesmo estilo.
class HomeWelcomeView extends StatelessWidget {
  const HomeWelcomeView({
    super.key,
    required this.onPick,
    required this.onOpenCategories,
  });

  final VoidCallback onPick;

  /// Abre a tela de categorias (criar/remover). Sem header (Etapa 6B), este
  /// é o caminho até ela quando ainda não há desenhos.
  final VoidCallback onOpenCategories;

  static const pickButtonKey = ValueKey('home-pick-image');
  static const categoriesButtonKey = ValueKey('home-categories');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Mesmo "molde" para os dois botões: mesma altura e mesmo estilo
    // preenchido. Lado a lado, nenhum parece "menos importante" por engano.
    // Etapa 6F: o molde foi para `core/`, porque o "Adicionar categoria"
    // também o usa.
    final buttonStyle = largeButtonStyle(theme);

    return _CenteredMessage(
      children: [
        // A marca no lugar do ícone grande das fases anteriores.
        const DesenhaAiLogo(height: 72),
        const SizedBox(height: 28),
        Text(
          'Escolha uma imagem de referência',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Use uma foto ou desenho salvo no aparelho. '
          'Nada é enviado para a internet.',
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        // `Expanded` nos dois: dividem a largura igualmente e cabem lado a
        // lado até num celular em pé (~360 dp).
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: pickButtonKey,
                onPressed: onPick,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text(
                  'Escolher imagem',
                  overflow: TextOverflow.ellipsis,
                ),
                style: buttonStyle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                key: categoriesButtonKey,
                onPressed: onOpenCategories,
                icon: const Icon(Icons.label_outline),
                label: const Text(
                  'Categorias',
                  overflow: TextOverflow.ellipsis,
                ),
                style: buttonStyle,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Indicador de progresso com uma mensagem ("Abrindo imagem…").
class HomeLoadingView extends StatelessWidget {
  const HomeLoadingView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _CenteredMessage(
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(message),
      ],
    );
  }
}

/// Erro ao abrir/copiar a imagem, com botão para tentar de novo.
class HomeErrorView extends StatelessWidget {
  const HomeErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _CenteredMessage(
      children: [
        Icon(Icons.error_outline, size: 72, color: theme.colorScheme.error),
        const SizedBox(height: 16),
        Text(
          message,
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Tentar novamente'),
        ),
      ],
    );
  }
}
