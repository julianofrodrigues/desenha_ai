import 'dart:math' as math;

import 'package:desenha_ai/features/drawing/models/overlay_transform.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('OverlayTransform', () {
    test('applyGesture soma deslocamento, multiplica escala e soma rotação',
        () {
      const start = OverlayTransform(
        offset: Offset(10, 20),
        scale: 2,
        rotation: 0.5,
      );

      final result = start.applyGesture(
        pan: const Offset(5, -5),
        scaleFactor: 1.5,
        rotationDelta: 0.25,
      );

      expect(result.offset, const Offset(15, 15));
      expect(result.scale, 3);
      expect(result.rotation, closeTo(0.75, 1e-9));
    });

    test('escala fica entre os limites', () {
      const start = OverlayTransform();
      expect(
        start
            .applyGesture(pan: Offset.zero, scaleFactor: 100, rotationDelta: 0)
            .scale,
        OverlayTransform.maxScale,
      );
      expect(
        start
            .applyGesture(pan: Offset.zero, scaleFactor: 0.001, rotationDelta: 0)
            .scale,
        OverlayTransform.minScale,
      );
    });

    test('rotação é normalizada entre -π e π', () {
      final result = const OverlayTransform().applyGesture(
        pan: Offset.zero,
        scaleFactor: 1,
        rotationDelta: 3 * math.pi, // uma volta e meia
      );
      expect(result.rotation, closeTo(math.pi, 1e-9));
    });

    test('resetPosition zera posição, zoom e rotação, mas mantém o espelho',
        () {
      const t = OverlayTransform(
        offset: Offset(50, 50),
        scale: 3,
        rotation: 1,
        flipped: true,
      );
      expect(t.resetPosition(), const OverlayTransform(flipped: true));
    });

    test('== compara por valor (evita rebuilds quando nada mudou)', () {
      expect(
        const OverlayTransform(scale: 2),
        const OverlayTransform(scale: 2),
      );
      expect(
        const OverlayTransform(scale: 2),
        isNot(const OverlayTransform(scale: 3)),
      );
    });

    test('toMatrix aplica deslocamento e espelha o eixo X', () {
      const t = OverlayTransform(offset: Offset(30, 40), flipped: true);
      final m = t.toMatrix();

      // Um ponto 10 px à direita do centro vai para 10 px à ESQUERDA
      // (espelhado) e depois é deslocado por (30, 40).
      final p = MatrixUtils.transformPoint(m, const Offset(10, 0));
      expect(p.dx, closeTo(20, 1e-9));
      expect(p.dy, closeTo(40, 1e-9));
    });
  });
}
