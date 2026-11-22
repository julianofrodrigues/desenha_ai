// Testa o gerador REAL de miniaturas (decodificador do Flutter).
//
// Decodificar imagens é trabalho assíncrono de verdade (fora do relógio falso
// dos widget tests), por isso tudo roda dentro de `tester.runAsync`.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:desenha_ai/features/projects/services/thumbnail_generator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Cria um PNG de [width]x[height] desenhado na hora.
Future<Uint8List> _png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = Colors.orange,
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<Size> _sizeOf(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
  final size = Size(image.width.toDouble(), image.height.toDouble());
  image.dispose();
  codec.dispose();
  return size;
}

void main() {
  testWidgets('reduz mantendo a proporção (maior lado = 256)',
      (tester) async {
    await tester.runAsync(() async {
      final thumb = await const UiThumbnailGenerator()
          .generate(await _png(1024, 512));
      expect(await _sizeOf(thumb), const Size(256, 128));
    });
  });

  testWidgets('imagens pequenas não são ampliadas', (tester) async {
    await tester.runAsync(() async {
      final thumb =
          await const UiThumbnailGenerator().generate(await _png(100, 80));
      expect(await _sizeOf(thumb), const Size(100, 80));
    });
  });

  testWidgets('bytes que não são imagem lançam erro', (tester) async {
    await tester.runAsync(() async {
      await expectLater(
        const UiThumbnailGenerator().generate(Uint8List.fromList([1, 2, 3])),
        throwsA(anything),
      );
    });
  });
}
