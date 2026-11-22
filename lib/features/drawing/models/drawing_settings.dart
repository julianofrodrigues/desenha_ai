import 'package:flutter/foundation.dart';

import 'drawing_mode.dart';
import 'overlay_transform.dart';

/// Tudo o que é preciso para restaurar a tela de desenho exatamente como o
/// usuário deixou: posição/zoom/rotação/espelho, opacidade e fundo.
///
/// A trava (`locked`) NÃO é salva de propósito: ao reabrir um desenho, a
/// pessoa precisa conseguir mexer na tela sem lembrar que a deixou travada.
@immutable
class DrawingSettings {
  const DrawingSettings({
    this.transform = const OverlayTransform(),
    this.opacity = defaultOpacity,
    this.mode = DrawingMode.camera,
    this.lightTableColor = LightTableColor.white,
  });

  /// 50%: dá para ver o papel e a referência ao mesmo tempo.
  static const double defaultOpacity = 0.5;

  /// Limites do slider. Abaixo de 10% a referência some e o usuário pode
  /// achar que a imagem "sumiu".
  static const double minOpacity = 0.1;
  static const double maxOpacity = 1.0;

  final OverlayTransform transform;
  final double opacity;
  final DrawingMode mode;
  final LightTableColor lightTableColor;

  DrawingSettings copyWith({
    OverlayTransform? transform,
    double? opacity,
    DrawingMode? mode,
    LightTableColor? lightTableColor,
  }) {
    return DrawingSettings(
      transform: transform ?? this.transform,
      opacity: opacity ?? this.opacity,
      mode: mode ?? this.mode,
      lightTableColor: lightTableColor ?? this.lightTableColor,
    );
  }

  Map<String, Object?> toJson() => {
        'transform': transform.toJson(),
        'opacity': opacity,
        'mode': mode.name,
        'lightTableColor': lightTableColor.name,
      };

  /// Tolerante a dados ausentes/inválidos (ver [OverlayTransform.fromJson]).
  factory DrawingSettings.fromJson(Map<String, Object?> json) {
    final transform = json['transform'];
    final opacity = json['opacity'];
    return DrawingSettings(
      transform: transform is Map<String, Object?>
          ? OverlayTransform.fromJson(transform)
          : const OverlayTransform(),
      opacity: opacity is num && opacity.isFinite
          ? opacity.toDouble().clamp(minOpacity, maxOpacity)
          : defaultOpacity,
      mode: enumByName(DrawingMode.values, json['mode'], DrawingMode.camera),
      lightTableColor: enumByName(
        LightTableColor.values,
        json['lightTableColor'],
        LightTableColor.white,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DrawingSettings &&
      other.transform == transform &&
      other.opacity == opacity &&
      other.mode == mode &&
      other.lightTableColor == lightTableColor;

  @override
  int get hashCode => Object.hash(transform, opacity, mode, lightTableColor);
}
