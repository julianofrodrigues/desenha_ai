import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Marca "Desenha A.I" em letras DESENHADAS (Fase 6, Etapa 6B).
///
/// Por que desenhar as letras, e não usar uma fonte "manuscrita"?
/// - 100% offline e sem arquivo extra: não há fonte para baixar nem embutir
///   no APK (fontes têm centenas de KB).
/// - Cada letra é uma lista de PONTOS por onde a "caneta" passa. O desenho
///   liga os pontos com curvas suaves, como um traço feito à mão, e passa um
///   segundo traço levemente deslocado, que lembra lápis sobre papel.
/// - Nítido em qualquer tamanho: é vetor, não imagem.
///
/// Desempenho: o contorno das letras é montado UMA vez (`static final`) num
/// espaço de "unidades". Ao pintar, só escalamos o canvas. Um
/// `RepaintBoundary` isola a marca: rolar a lista ou mexer na busca não a
/// repinta.
class DesenhaAiLogo extends StatelessWidget {
  const DesenhaAiLogo({super.key, this.height = 64});

  /// Texto da marca (também é o rótulo para o leitor de tela).
  static const text = 'Desenha A.I';

  /// Altura das letras maiúsculas, em dp.
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final width = height * _LogoGlyphs.aspectRatio;

    return Semantics(
      label: text,
      header: true,
      excludeSemantics: true,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size(width, height),
          painter: DesenhaAiLogoPainter(
            // Cores do tema (violeta → turquesa): a marca acompanha o modo
            // claro/escuro sem nenhum código extra.
            start: colors.primary,
            end: colors.secondary,
            sketch: colors.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Pinta a marca. Pública só para os testes conferirem as cores usadas.
class DesenhaAiLogoPainter extends CustomPainter {
  const DesenhaAiLogoPainter({
    required this.start,
    required this.end,
    required this.sketch,
  });

  /// Começo e fim do degradê do traço principal.
  final Color start;
  final Color end;

  /// Cor do traço de "lápis" (bem transparente).
  final Color sketch;

  @override
  void paint(Canvas canvas, Size size) {
    // Unidades → pixels: cabe na caixa, centralizado, sem distorcer.
    final scale = math.min(
      size.width / _LogoGlyphs.width,
      size.height / _LogoGlyphs.height,
    );
    final dx = (size.width - _LogoGlyphs.width * scale) / 2;
    final dy = (size.height - _LogoGlyphs.height * scale) / 2;

    canvas
      ..save()
      ..translate(dx, dy)
      ..scale(scale);

    final bounds =
        Rect.fromLTWH(0, 0, _LogoGlyphs.width, _LogoGlyphs.height);

    // 1º o "lápis": mais fino, transparente e um pouco deslocado. Fica por
    // baixo e dá a impressão de esboço antes da tinta.
    canvas
      ..save()
      ..translate(0.025, 0.02)
      ..drawPath(
        _LogoGlyphs.path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.035
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = sketch.withValues(alpha: 0.22)
          ..isAntiAlias = true,
      )
      ..restore();

    // 2º a "tinta": traço principal com degradê.
    canvas.drawPath(
      _LogoGlyphs.path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.085
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(colors: [start, end]).createShader(bounds)
        ..isAntiAlias = true,
    );

    canvas.restore();
  }

  // Só repinta se as CORES mudarem (troca de tema). O formato é fixo.
  @override
  bool shouldRepaint(DesenhaAiLogoPainter old) =>
      old.start != start || old.end != end || old.sketch != sketch;
}

/// As letras de "Desenha A.I" como traços de caneta.
///
/// Sistema de coordenadas de cada letra:
/// - y = 0 é o topo das maiúsculas e y = 1 é a linha de base;
/// - as minúsculas começam em y ≈ 0.4 (a "altura do x");
/// - x vai de 0 até a largura da letra.
abstract final class _LogoGlyphs {
  /// Espaço entre letras, em unidades.
  static const _spacing = 0.12;

  /// Margem para a espessura do traço não ser cortada nas bordas.
  static const _margin = 0.08;

  static const height = 1 + _margin * 2;

  static final ({Path path, double width}) _built = _build();

  static Path get path => _built.path;
  static double get width => _built.width;
  static double get aspectRatio => width / height;

  /// Cada letra: largura + traços (cada traço é uma lista de pontos).
  static const Map<String, (double, List<List<Offset>>)> _glyphs = {
    'D': (0.7, [
      [Offset(0, 0), Offset(0, 1)],
      [
        Offset(0, 0), Offset(0.35, 0.02), Offset(0.64, 0.24), Offset(0.7, 0.5), //
        Offset(0.64, 0.76), Offset(0.35, 0.98), Offset(0, 1),
      ],
    ]),
    'e': (0.5, [
      [
        Offset(0.05, 0.7), Offset(0.46, 0.7), Offset(0.42, 0.51), //
        Offset(0.25, 0.41), Offset(0.08, 0.51), Offset(0.03, 0.72),
        Offset(0.1, 0.92), Offset(0.28, 1), Offset(0.47, 0.93),
      ],
    ]),
    's': (0.42, [
      [
        Offset(0.4, 0.47), Offset(0.25, 0.4), Offset(0.07, 0.47), //
        Offset(0.08, 0.62), Offset(0.25, 0.7), Offset(0.38, 0.78),
        Offset(0.38, 0.93), Offset(0.2, 1), Offset(0.02, 0.93),
      ],
    ]),
    'n': (0.48, [
      [Offset(0.03, 0.4), Offset(0.03, 1)],
      [
        Offset(0.03, 0.56), Offset(0.15, 0.43), Offset(0.3, 0.4), //
        Offset(0.43, 0.48), Offset(0.45, 0.66), Offset(0.45, 1),
      ],
    ]),
    'h': (0.48, [
      [Offset(0.03, 0), Offset(0.03, 1)],
      [
        Offset(0.03, 0.56), Offset(0.15, 0.43), Offset(0.3, 0.4), //
        Offset(0.43, 0.48), Offset(0.45, 0.66), Offset(0.45, 1),
      ],
    ]),
    'a': (0.5, [
      [
        Offset(0.42, 0.5), Offset(0.3, 0.41), Offset(0.13, 0.45), //
        Offset(0.03, 0.65), Offset(0.07, 0.9), Offset(0.22, 1),
        Offset(0.38, 0.93), Offset(0.44, 0.75),
      ],
      [Offset(0.44, 0.42), Offset(0.44, 0.9), Offset(0.5, 1)],
    ]),
    ' ': (0.3, []),
    'A': (0.75, [
      [Offset(0, 1), Offset(0.37, 0), Offset(0.75, 1)],
      [Offset(0.16, 0.62), Offset(0.6, 0.6)],
    ]),
    // Um traço curtíssimo com ponta redonda vira um "ponto" de caneta.
    '.': (0.16, [
      [Offset(0.07, 0.96), Offset(0.09, 0.98)],
    ]),
    'I': (0.32, [
      [Offset(0.16, 0), Offset(0.16, 1)],
      [Offset(0, 0), Offset(0.32, 0)],
      [Offset(0, 1), Offset(0.32, 1)],
    ]),
  };

  static ({Path path, double width}) _build() {
    final path = Path();
    var x = _margin;
    final letters = DesenhaAiLogo.text.split('');
    for (var i = 0; i < letters.length; i++) {
      final (letterWidth, strokes) = _glyphs[letters[i]]!;
      for (final stroke in strokes) {
        _addStroke(path, stroke, Offset(x, _margin));
      }
      x += letterWidth;
      if (i < letters.length - 1) x += _spacing;
    }
    return (path: path, width: x + _margin);
  }

  /// Liga os pontos com curvas: cada ponto do meio vira o "puxador" de uma
  /// curva quadrática que termina no meio do caminho até o próximo ponto.
  /// O resultado passa perto de todos os pontos, sem quinas, como um traço
  /// feito à mão. Traços de 2 pontos viram retas.
  static void _addStroke(Path path, List<Offset> points, Offset origin) {
    final p = [for (final point in points) point + origin];
    path.moveTo(p.first.dx, p.first.dy);
    for (var i = 1; i < p.length - 1; i++) {
      final mid = Offset.lerp(p[i], p[i + 1], 0.5)!;
      path.quadraticBezierTo(p[i].dx, p[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(p.last.dx, p.last.dy);
  }
}
