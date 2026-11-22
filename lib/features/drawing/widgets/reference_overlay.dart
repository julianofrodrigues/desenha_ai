import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../models/overlay_transform.dart';

/// Imagem de referência por cima do fundo, com gestos multitoque.
///
/// - 1 dedo: arrasta.
/// - 2 dedos: pinça (zoom) e giro (rotação), ao mesmo tempo que arrasta.
///
/// Os gestos valem na TELA INTEIRA, não só sobre a imagem. Assim dá para
/// ajustar uma imagem que ficou pequena ou fora da tela sem "caçá-la".
///
/// Desempenho: durante um gesto o [transform] muda ~60 vezes por segundo.
/// Por isso só o widget `Transform` escuta o notifier. A imagem decodificada,
/// a opacidade e o detector de gestos NÃO são reconstruídos a cada quadro.
class ReferenceOverlay extends StatefulWidget {
  const ReferenceOverlay({
    super.key,
    required this.bytes,
    required this.transform,
    required this.opacity,
  });

  final Uint8List bytes;
  final ValueNotifier<OverlayTransform> transform;
  final ValueListenable<double> opacity;

  @override
  State<ReferenceOverlay> createState() => _ReferenceOverlayState();
}

class _ReferenceOverlayState extends State<ReferenceOverlay> {
  /// Estado da imagem e posição dos dedos no INÍCIO do gesto atual.
  /// Os valores de `ScaleUpdateDetails` são relativos a esse início.
  OverlayTransform? _gestureStart;
  Offset _gestureStartFocalPoint = Offset.zero;

  ImageProvider? _provider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Criado uma única vez (precisamos do `MediaQuery`, que só está
    // disponível aqui, e não no `initState`).
    _provider ??= _buildProvider();
  }

  /// Decodifica a imagem com até 2x o MAIOR lado da tela, em pixels físicos.
  ///
  /// - 2x: dá margem para o zoom sem pixelar logo de cara.
  /// - Maior lado: o valor não muda ao girar o aparelho, então a imagem não é
  ///   decodificada de novo a cada rotação.
  /// - Limite: uma foto de 50 MP decodificada inteira usaria ~200 MB de RAM;
  ///   assim ficamos na casa de dezenas de MB no Galaxy Tab A.
  ImageProvider _buildProvider() {
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final target = (size.longestSide * dpr * 2).round();
    final memory = MemoryImage(widget.bytes);
    if (target <= 0) return memory;
    return ResizeImage(
      memory,
      width: target,
      height: target,
      policy: ResizeImagePolicy.fit, // mantém a proporção, sem ampliar
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    // O Flutter chama `onScaleStart` de novo quando um dedo entra ou sai no
    // meio do gesto. Guardar o estado ATUAL aqui evita "pulos" da imagem.
    _gestureStart = widget.transform.value;
    _gestureStartFocalPoint = details.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final start = _gestureStart;
    if (start == null) return;
    widget.transform.value = start.applyGesture(
      pan: details.focalPoint - _gestureStartFocalPoint,
      scaleFactor: details.scale,
      rotationDelta: details.rotation,
    );
  }

  void _onScaleEnd(ScaleEndDetails details) => _gestureStart = null;

  @override
  Widget build(BuildContext context) {
    // Montada UMA vez por build deste State (que quase nunca acontece) e
    // passada como `child` aos builders abaixo.
    //
    // `RepaintBoundary`: a imagem é pintada numa camada própria. Ao mover ou
    // mudar a opacidade, o Flutter reaproveita essa camada já pintada e só a
    // recompõe, sem redesenhar os pixels da imagem.
    final image = RepaintBoundary(
      child: Image(
        image: _provider!,
        fit: BoxFit.contain,
        // Evita piscar caso o provider seja recriado.
        gaplessPlayback: true,
        semanticLabel: 'Imagem de referência',
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Text(
            'Não foi possível exibir a imagem.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );

    return GestureDetector(
      // `opaque`: recebe toques mesmo em áreas transparentes (fora da imagem).
      behavior: HitTestBehavior.opaque,
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: _onScaleEnd,
      child: SizedBox.expand(
        child: ValueListenableBuilder<OverlayTransform>(
          valueListenable: widget.transform,
          builder: (context, transform, child) => Transform(
            transform: transform.toMatrix(),
            // Origem no centro: rotação e zoom acontecem em volta do centro
            // da imagem, que é o que o usuário espera.
            alignment: Alignment.center,
            child: child,
          ),
          child: ValueListenableBuilder<double>(
            valueListenable: widget.opacity,
            builder: (context, opacity, child) =>
                Opacity(opacity: opacity, child: child),
            child: image,
          ),
        ),
      ),
    );
  }
}
