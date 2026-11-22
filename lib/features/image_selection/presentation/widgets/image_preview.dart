import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

/// Mostra a prévia de uma imagem que já está na memória (bytes).
///
/// Cuida dos dois problemas que aparecem DEPOIS que o arquivo foi lido:
/// 1. Decodificar a imagem leva tempo (uma foto de câmera tem milhões de
///    pixels). Enquanto isso, mostramos um indicador de carregamento.
/// 2. O arquivo pode estar corrompido ou num formato que o Flutter não
///    decodifica. Nesse caso mostramos uma mensagem em vez de quebrar a tela.
class ImagePreview extends StatelessWidget {
  const ImagePreview({super.key, required this.bytes, this.onRetry});

  final Uint8List bytes;

  /// Chamado quando o usuário toca em "Escolher outra" depois de um erro de
  /// decodificação. É opcional para que o widget sirva em outros lugares.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    // `LayoutBuilder` informa quanto espaço este widget recebeu do pai.
    // Usamos isso para decodificar a imagem no TAMANHO DA ÁREA DE PRÉVIA,
    // e não no tamanho original.
    //
    // Por quê? Uma foto de 50 MP do RedMagic ocupa ~200 MB de RAM quando
    // decodificada inteira (largura x altura x 4 bytes por pixel). Na prévia
    // só precisamos de uns poucos milhões de pixels. Isso evita travamentos
    // e "Out of memory" no Galaxy Tab A, que tem pouca RAM.
    return LayoutBuilder(
      builder: (context, constraints) {
        // Pixels lógicos x densidade da tela = pixels físicos reais.
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final targetWidth = _toPhysical(constraints.maxWidth, dpr);
        final targetHeight = _toPhysical(constraints.maxHeight, dpr);

        // Se o pai não limitou o espaço (ex.: dentro de uma lista rolável),
        // não há tamanho-alvo e decodificamos no tamanho original.
        final ImageProvider memory = MemoryImage(bytes);
        final ImageProvider provider =
            (targetWidth == null || targetHeight == null)
                ? memory
                : ResizeImage(
                    memory,
                    width: targetWidth,
                    height: targetHeight,
                    // `fit`: cabe na caixa mantendo a proporção. Como
                    // `allowUpscaling` é falso por padrão, imagens pequenas
                    // não são aumentadas à toa na memória.
                    policy: ResizeImagePolicy.fit,
                  );

        return Image(
          image: provider,
          // Ocupa a área toda; o `fit` abaixo centraliza a imagem dentro dela.
          // Sem isso, uma imagem pequena ficaria grudada no canto do cartão.
          width: constraints.hasBoundedWidth ? constraints.maxWidth : null,
          height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
          // `contain` mostra a imagem inteira, sem cortes. Numa referência de
          // desenho, cortar as bordas esconderia parte do que vai ser copiado.
          fit: BoxFit.contain,
          // Rótulo para leitores de tela (acessibilidade).
          semanticLabel: 'Prévia da imagem escolhida',
          // Loading da DECODIFICAÇÃO: `frameBuilder` é chamado de novo quando
          // o primeiro quadro fica pronto. Enquanto `frame` for null, ainda
          // não há nada para desenhar.
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) return child;
            return const Center(child: CircularProgressIndicator());
          },
          // Erro da DECODIFICAÇÃO (arquivo corrompido, formato não suportado).
          errorBuilder: (context, error, stackTrace) =>
              _DecodeError(onRetry: onRetry),
        );
      },
    );
  }
}

/// Converte um tamanho lógico em pixels físicos, ou `null` se o tamanho for
/// infinito/zero (não dá para decodificar uma imagem com 0 ou ∞ pixels).
int? _toPhysical(double logical, double dpr) {
  if (!logical.isFinite || logical <= 0) return null;
  return (logical * dpr).round();
}

class _DecodeError extends StatelessWidget {
  const _DecodeError({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, size: 56, color: colors.error),
            const SizedBox(height: 12),
            const Text(
              'Não foi possível abrir esta imagem.\n'
              'O arquivo pode estar corrompido ou em um formato não suportado.',
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Escolher outra'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
