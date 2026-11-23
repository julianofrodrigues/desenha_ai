// Telas de estado da Home: boas-vindas, carregando e erro.
//
// Saíram da `home_page.dart` na Fase 4, para a tela não passar do tamanho
// recomendado pelo steering (~300 linhas). Cada estado tem seu próprio
// widget pequeno: o `build` da Home fica só com o `switch`, e o Flutter
// reconstrói só a parte que mudou.
import 'package:material_ui/material_ui.dart';

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
class HomeWelcomeView extends StatelessWidget {
  const HomeWelcomeView({super.key, required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _CenteredMessage(
      children: [
        Icon(
          Icons.draw_outlined,
          size: 96,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 24),
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
        // Um único botão principal e grande: nesta tela só existe uma ação
        // possível, então não há o que o usuário precise decidir.
        FilledButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Escolher imagem'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(220, 56),
            textStyle: theme.textTheme.titleMedium,
          ),
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
