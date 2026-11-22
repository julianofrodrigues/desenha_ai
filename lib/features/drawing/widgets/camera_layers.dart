import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../services/camera_service.dart';

/// Fundo do Modo Câmera: imagem ao vivo da câmera em tela cheia.
///
/// Escuta só o [status]: reconstrói quando a câmera liga/desliga, e não a
/// cada quadro de vídeo (os quadros chegam direto numa `Texture` nativa, sem
/// passar pelo `build`).
class CameraPreviewLayer extends StatelessWidget {
  const CameraPreviewLayer({super.key, required this.status});

  final ValueListenable<CameraStatus> status;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CameraStatus>(
      valueListenable: status,
      builder: (context, status, _) => switch (status) {
        CameraReady(:final controller) => _CoverPreview(controller),
        // Enquanto não há imagem, fundo preto (o painel de status, desenhado
        // por cima, explica o que está acontecendo).
        _ => const ColoredBox(color: Colors.black),
      },
    );
  }
}

/// Preview que PREENCHE a tela (como `BoxFit.cover`), cortando as sobras.
///
/// O `CameraPreview` sozinho mantém a proporção do sensor (ex.: 4:3) e deixa
/// faixas pretas numa tela 16:10. Para AR, preencher tudo é melhor; perder
/// um pouco das bordas da imagem da câmera não atrapalha.
class _CoverPreview extends StatelessWidget {
  const _CoverPreview(this.controller);

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return CameraPreview(controller);

    // O sensor informa o tamanho em paisagem (largura > altura). Em retrato,
    // invertemos para casar com a orientação da tela.
    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    final width = isPortrait ? previewSize.height : previewSize.width;
    final height = isPortrait ? previewSize.width : previewSize.height;

    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: width,
            height: height,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}

/// Mensagens sobre a câmera (abrindo, sem permissão, indisponível),
/// desenhadas POR CIMA da imagem de referência para ficarem visíveis.
///
/// Fora do cartão, os toques passam direto para a camada de gestos abaixo.
class CameraStatusPanel extends StatelessWidget {
  const CameraStatusPanel({
    super.key,
    required this.status,
    required this.onUseLightTable,
    required this.onRetry,
  });

  final ValueListenable<CameraStatus> status;
  final VoidCallback onUseLightTable;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CameraStatus>(
      valueListenable: status,
      builder: (context, status, _) => switch (status) {
        CameraStarting() => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Abrindo câmera…', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        CameraPermissionDenied() => _ProblemCard(
            icon: Icons.no_photography_outlined,
            title: 'Sem acesso à câmera',
            message: 'Você pode continuar desenhando no Modo Mesa de Luz.\n'
                'Para usar a câmera depois, permita o acesso em '
                'Configurações › Apps › desenha_ai › Permissões.',
            onUseLightTable: onUseLightTable,
            onRetry: onRetry,
          ),
        CameraUnavailable(:final message) => _ProblemCard(
            icon: Icons.videocam_off_outlined,
            title: 'Câmera indisponível',
            message: '$message\nVocê pode continuar no Modo Mesa de Luz.',
            onUseLightTable: onUseLightTable,
            onRetry: onRetry,
          ),
        CameraOff() || CameraReady() => const SizedBox.shrink(),
      },
    );
  }
}

class _ProblemCard extends StatelessWidget {
  const _ProblemCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.onUseLightTable,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onUseLightTable;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 48, color: theme.colorScheme.error),
                  const SizedBox(height: 12),
                  Text(title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  // A ação recomendada (continuar sem câmera) é o botão
                  // principal: o usuário nunca fica "preso" nesta mensagem.
                  FilledButton.icon(
                    onPressed: onUseLightTable,
                    icon: const Icon(Icons.light_mode_outlined),
                    label: const Text('Usar Mesa de Luz'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
