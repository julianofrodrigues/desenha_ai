import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Gera uma miniatura pequena (PNG) a partir da imagem original.
abstract interface class ThumbnailGenerator {
  /// Lança uma exceção se a imagem não puder ser decodificada.
  Future<Uint8List> generate(Uint8List imageBytes);
}

/// Implementação com o decodificador de imagens do próprio Flutter
/// (`dart:ui`), sem pacotes extras.
///
/// Por que gerar e GUARDAR uma miniatura, em vez de mostrar a imagem
/// original reduzida na lista?
/// - Uma foto de câmera tem vários MB. Ler e decodificar uma dessas por item
///   da lista, toda vez que a Home abre, é lento e pesa na RAM do Galaxy
///   Tab A.
/// - A miniatura tem poucas dezenas de KB e é gerada UMA vez, ao criar o
///   projeto.
class UiThumbnailGenerator implements ThumbnailGenerator {
  const UiThumbnailGenerator({this.maxSide = 256});

  /// Maior lado da miniatura, em pixels. 256 px dá nitidez até para um item
  /// de ~85 dp numa tela de densidade 3x.
  final int maxSide;

  @override
  Future<Uint8List> generate(Uint8List imageBytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(imageBytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    ui.Codec? codec;
    ui.Image? image;
    try {
      // O descritor lê só o CABEÇALHO do arquivo (largura/altura), sem
      // decodificar os pixels. Com isso calculamos o tamanho final mantendo
      // a proporção.
      final width = descriptor.width;
      final height = descriptor.height;
      final scale = math.min(1.0, maxSide / math.max(width, height));

      // Pedir o tamanho-alvo ao codec deixa o decodificador reduzir a imagem
      // durante a leitura (em JPEG, por exemplo, ele pode decodificar direto
      // em 1/2, 1/4 ou 1/8), em vez de montar a foto inteira na memória
      // primeiro.
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (width * scale).round()),
        targetHeight: math.max(1, (height * scale).round()),
      );
      image = (await codec.getNextFrame()).image;

      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) {
        throw StateError('Não foi possível codificar a miniatura.');
      }
      return png.buffer.asUint8List();
    } finally {
      // Objetos de `dart:ui` seguram memória NATIVA (fora do coletor de lixo
      // do Dart). Liberamos explicitamente assim que terminamos.
      image?.dispose();
      codec?.dispose();
      descriptor.dispose();
      buffer.dispose();
    }
  }
}
