import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Posição, tamanho, rotação e espelhamento da imagem de referência.
///
/// É IMUTÁVEL: para mudar, criamos uma cópia com [copyWith]. Por quê?
/// - O `ValueNotifier` só avisa os ouvintes quando recebe um objeto
///   DIFERENTE (`!=`). Com objetos imutáveis e `==` implementado, atribuir o
///   mesmo valor não causa rebuild à toa.
/// - Na Fase 3 este objeto vai ser salvo em disco; dados imutáveis são mais
///   fáceis de serializar e comparar.
@immutable
class OverlayTransform {
  const OverlayTransform({
    this.offset = Offset.zero,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.flipped = false,
  });

  /// Limites do zoom. Abaixo de 10% a imagem some; acima de 10x a imagem
  /// decodificada fica pixelada e o gesto perde precisão.
  static const double minScale = 0.1;
  static const double maxScale = 10.0;

  /// Deslocamento a partir do centro da tela, em pixels lógicos.
  final Offset offset;

  /// 1.0 = imagem ajustada à tela (BoxFit.contain).
  final double scale;

  /// Rotação em radianos (sentido horário na tela).
  final double rotation;

  /// Espelhado horizontalmente.
  final bool flipped;

  OverlayTransform copyWith({
    Offset? offset,
    double? scale,
    double? rotation,
    bool? flipped,
  }) {
    return OverlayTransform(
      offset: offset ?? this.offset,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      flipped: flipped ?? this.flipped,
    );
  }

  /// Aplica um gesto multitoque a partir do estado do INÍCIO do gesto.
  ///
  /// Recebe valores acumulados desde o início (é assim que o
  /// `ScaleUpdateDetails` do Flutter informa `scale` e `rotation`). Calcular
  /// sempre a partir de [this] (estado inicial), e não somando pequenos
  /// passos, evita acúmulo de erro de arredondamento ao longo do gesto.
  ///
  /// - [pan]: quanto o ponto focal (centro entre os dedos) andou.
  /// - [scaleFactor]: 1.0 = sem mudança; 2.0 = dedos 2x mais afastados.
  /// - [rotationDelta]: quanto os dedos giraram, em radianos.
  OverlayTransform applyGesture({
    required Offset pan,
    required double scaleFactor,
    required double rotationDelta,
  }) {
    return copyWith(
      offset: offset + pan,
      scale: (scale * scaleFactor).clamp(minScale, maxScale),
      rotation: _normalizeAngle(rotation + rotationDelta),
    );
  }

  /// Volta posição, zoom e rotação ao padrão. O espelhamento é mantido: é
  /// uma escolha de "como desenhar", não um ajuste de posição.
  OverlayTransform resetPosition() => OverlayTransform(flipped: flipped);

  /// Converte em uma matriz 4x4 para o widget `Transform`.
  ///
  /// A ordem importa (as operações são aplicadas da direita para a esquerda
  /// sobre cada ponto da imagem): primeiro espelha e escala, depois rotaciona,
  /// por último desloca. Se deslocássemos antes de rotacionar, a imagem
  /// giraria em volta do centro da TELA, e não do próprio centro.
  ///
  /// A origem (0,0) é o centro da imagem porque o `Transform` usa
  /// `alignment: Alignment.center`.
  Matrix4 toMatrix() {
    return Matrix4.identity()
      ..translateByDouble(offset.dx, offset.dy, 0, 1)
      ..rotateZ(rotation)
      ..scaleByDouble(flipped ? -scale : scale, scale, 1, 1);
  }

  // -------------------------------------------------------------------------
  // JSON (Fase 3)
  // -------------------------------------------------------------------------
  //
  // Salvamos os COMPONENTES (posição, zoom, rotação, espelho), e não os 16
  // números da Matrix4. Por quê?
  // - A matriz é sempre recalculada a partir deles por `toMatrix()`, então
  //   nada se perde.
  // - Componentes são legíveis no arquivo e podem ser VALIDADOS ao carregar
  //   (zoom dentro dos limites, ângulo normalizado). Uma matriz corrompida
  //   poderia distorcer a imagem de formas que a UI nem consegue desfazer.
  // - Extrair zoom/rotação de volta de uma matriz (decomposição) é sujeito a
  //   erro de arredondamento e ambíguo quando há espelhamento.

  Map<String, Object?> toJson() => {
        'dx': offset.dx,
        'dy': offset.dy,
        'scale': scale,
        'rotation': rotation,
        'flipped': flipped,
      };

  /// Lê de JSON tolerando arquivos antigos ou corrompidos: campos ausentes
  /// ou inválidos voltam ao padrão, e valores fora dos limites são ajustados.
  factory OverlayTransform.fromJson(Map<String, Object?> json) {
    double read(String key, double fallback) {
      final value = json[key];
      // `jsonDecode` devolve `int` para "1" e `double` para "1.5": aceitamos
      // qualquer `num`. NaN/infinito nunca são válidos aqui.
      return value is num && value.isFinite ? value.toDouble() : fallback;
    }

    return OverlayTransform(
      offset: Offset(read('dx', 0), read('dy', 0)),
      scale: read('scale', 1).clamp(minScale, maxScale),
      rotation: _normalizeAngle(read('rotation', 0)),
      flipped: json['flipped'] == true,
    );
  }

  /// Mantém o ângulo entre -π e π, para o número não crescer sem limite
  /// depois de muitas voltas (útil também ao salvar na Fase 3).
  static double _normalizeAngle(double radians) {
    final twoPi = 2 * math.pi;
    var a = radians % twoPi;
    if (a > math.pi) a -= twoPi;
    return a;
  }

  @override
  bool operator ==(Object other) =>
      other is OverlayTransform &&
      other.offset == offset &&
      other.scale == scale &&
      other.rotation == rotation &&
      other.flipped == flipped;

  @override
  int get hashCode => Object.hash(offset, scale, rotation, flipped);

  @override
  String toString() =>
      'OverlayTransform(offset: $offset, scale: $scale, rotation: $rotation, '
      'flipped: $flipped)';
}
