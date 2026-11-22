// Serialização JSON dos modelos: ida e volta sem perda, e tolerância a
// arquivos antigos/corrompidos.
import 'dart:convert';
import 'dart:math' as math;

import 'package:desenha_ai/features/drawing/models/drawing_mode.dart';
import 'package:desenha_ai/features/drawing/models/drawing_settings.dart';
import 'package:desenha_ai/features/drawing/models/overlay_transform.dart';
import 'package:desenha_ai/features/projects/models/drawing_project.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simula gravar e ler do disco: objeto → texto JSON → objeto.
Map<String, Object?> _roundTrip(Map<String, Object?> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;

void main() {
  const settings = DrawingSettings(
    transform: OverlayTransform(
      offset: Offset(-12.5, 300),
      scale: 3.25,
      rotation: -2.5,
      flipped: true,
    ),
    opacity: 0.35,
    mode: DrawingMode.lightTable,
    lightTableColor: LightTableColor.black,
  );

  test('DrawingSettings: ida e volta sem perda', () {
    expect(DrawingSettings.fromJson(_roundTrip(settings.toJson())), settings);
  });

  test('a matriz reconstruída é idêntica à original', () {
    final restored = DrawingSettings.fromJson(_roundTrip(settings.toJson()));
    expect(restored.transform.toMatrix(), settings.transform.toMatrix());
  });

  test('DrawingSettings: valores inválidos voltam ao padrão ou são ajustados',
      () {
    final restored = DrawingSettings.fromJson({
      'transform': {'dx': 'abc', 'scale': 999, 'rotation': 7 * math.pi},
      'opacity': 0.01,
      'mode': 'modoQueNaoExiste',
      // lightTableColor ausente
    });

    expect(restored.transform.offset, Offset.zero);
    expect(restored.transform.scale, OverlayTransform.maxScale);
    expect(restored.transform.rotation.abs(), lessThanOrEqualTo(math.pi));
    expect(restored.opacity, DrawingSettings.minOpacity);
    expect(restored.mode, DrawingMode.camera);
    expect(restored.lightTableColor, LightTableColor.white);
  });

  test('números inteiros no JSON ("scale": 2) também são aceitos', () {
    final t = OverlayTransform.fromJson({'scale': 2, 'dx': 10, 'dy': 0});
    expect(t.scale, 2.0);
    expect(t.offset, const Offset(10, 0));
  });

  group('DrawingProject', () {
    final project = DrawingProject(
      id: 'abc123',
      originalName: 'gato.jpg',
      imageFileName: 'image.jpg',
      thumbnailFileName: 'thumb.png',
      createdAt: DateTime(2025, 1, 2, 3, 4, 5),
      updatedAt: DateTime(2025, 6, 7, 8, 9, 10),
      settings: settings,
    );

    test('ida e volta sem perda', () {
      expect(DrawingProject.fromJson(_roundTrip(project.toJson())), project);
    });

    test('datas são salvas em UTC (ISO 8601)', () {
      final json = project.toJson();
      expect(json['updatedAt'], endsWith('Z'));
    });

    test('rejeita nomes de arquivo que saem da pasta do projeto', () {
      final json = project.toJson()..['imageFile'] = '../../segredo.txt';
      expect(() => DrawingProject.fromJson(json), throwsFormatException);
    });

    test('rejeita id que não pode ser nome de pasta', () {
      final json = project.toJson()..['id'] = '../x';
      expect(() => DrawingProject.fromJson(json), throwsFormatException);
    });

    test('rejeita arquivo de uma versão mais nova do app', () {
      final json = project.toJson()
        ..['schemaVersion'] = DrawingProject.schemaVersion + 1;
      expect(() => DrawingProject.fromJson(json), throwsFormatException);
    });

    test('ajustes ausentes não impedem abrir o projeto', () {
      final json = project.toJson()..remove('settings');
      expect(
        DrawingProject.fromJson(json).settings,
        const DrawingSettings(),
      );
    });
  });
}
