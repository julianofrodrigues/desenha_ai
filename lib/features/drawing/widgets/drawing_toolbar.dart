import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../models/drawing_mode.dart';
import '../models/overlay_transform.dart';
import '../services/camera_service.dart';

/// Painel inferior com os controles da tela de desenho.
///
/// É um `StatelessWidget` que NUNCA é reconstruído por inteiro durante o uso:
/// cada controle escuta só o notifier de que depende. Mexer no slider de
/// opacidade, por exemplo, reconstrói só o slider e o texto da porcentagem.
class DrawingToolbar extends StatelessWidget {
  const DrawingToolbar({
    super.key,
    required this.opacity,
    required this.mode,
    required this.lightTableColor,
    required this.transform,
    required this.camera,
    required this.onResetPosition,
    required this.onToggleFlip,
  });

  final ValueNotifier<double> opacity;
  final ValueNotifier<DrawingMode> mode;
  final ValueNotifier<LightTableColor> lightTableColor;
  final ValueListenable<OverlayTransform> transform;
  final CameraService camera;
  final VoidCallback onResetPosition;
  final VoidCallback onToggleFlip;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // Fundo escuro translúcido: os controles ficam legíveis sobre qualquer
      // imagem da câmera, sem esconder totalmente o que está atrás.
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OpacitySlider(opacity: opacity),
            // `Wrap` quebra a linha em celulares em pé, onde nem todos os
            // botões cabem lado a lado.
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                _ModeSelector(mode: mode),
                _LightTableColorButton(mode: mode, color: lightTableColor),
                _TorchButton(mode: mode, camera: camera),
                _FlipButton(transform: transform, onPressed: onToggleFlip),
                IconButton(
                  tooltip: 'Resetar posição',
                  onPressed: onResetPosition,
                  icon: const Icon(Icons.center_focus_strong_outlined),
                  color: Colors.white,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OpacitySlider extends StatelessWidget {
  const _OpacitySlider({required this.opacity});

  final ValueNotifier<double> opacity;

  static const min = 0.1;
  static const max = 1.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.opacity, color: Colors.white),
        Expanded(
          child: ValueListenableBuilder<double>(
            valueListenable: opacity,
            builder: (context, value, _) => Slider(
              value: value,
              min: min,
              max: max,
              // Passos de 5%: precisão suficiente e o slider fica mais fácil
              // de acertar com o dedo.
              divisions: 18,
              label: _percent(value),
              semanticFormatterCallback: _percent,
              // Atribuir ao notifier atualiza só quem o escuta (a imagem e
              // este slider), sem `setState` na tela.
              onChanged: (v) => opacity.value = v,
            ),
          ),
        ),
        SizedBox(
          width: 48,
          child: ValueListenableBuilder<double>(
            valueListenable: opacity,
            builder: (context, value, _) => Text(
              _percent(value),
              textAlign: TextAlign.end,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  static String _percent(double v) => '${(v * 100).round()}%';
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.mode});

  final ValueNotifier<DrawingMode> mode;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DrawingMode>(
      valueListenable: mode,
      builder: (context, current, _) => SegmentedButton<DrawingMode>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          foregroundColor: Colors.white,
          selectedForegroundColor: Colors.black,
          selectedBackgroundColor: Colors.white,
        ),
        segments: const [
          ButtonSegment(
            value: DrawingMode.camera,
            icon: Icon(Icons.photo_camera_outlined),
            label: Text('Câmera'),
          ),
          ButtonSegment(
            value: DrawingMode.lightTable,
            icon: Icon(Icons.light_mode_outlined),
            label: Text('Mesa de luz'),
          ),
        ],
        selected: {current},
        onSelectionChanged: (selection) => mode.value = selection.first,
      ),
    );
  }
}

/// Alterna fundo branco/preto. Só aparece no Modo Mesa de Luz.
class _LightTableColorButton extends StatelessWidget {
  const _LightTableColorButton({required this.mode, required this.color});

  final ValueListenable<DrawingMode> mode;
  final ValueNotifier<LightTableColor> color;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([mode, color]),
      builder: (context, _) {
        if (mode.value != DrawingMode.lightTable) {
          return const SizedBox.shrink();
        }
        final isWhite = color.value == LightTableColor.white;
        return IconButton(
          tooltip: isWhite ? 'Fundo preto' : 'Fundo branco',
          onPressed: () => color.value =
              isWhite ? LightTableColor.black : LightTableColor.white,
          icon: Icon(isWhite ? Icons.dark_mode_outlined : Icons.wb_sunny),
          color: Colors.white,
        );
      },
    );
  }
}

/// Lanterna. Só aparece com a câmera pronta.
class _TorchButton extends StatelessWidget {
  const _TorchButton({required this.mode, required this.camera});

  final ValueListenable<DrawingMode> mode;
  final CameraService camera;

  Future<void> _toggle(BuildContext context) async {
    final ok = await camera.setTorch(!camera.torchOn.value);
    // Depois do `await`, o widget pode ter saído da tela.
    if (ok || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Este aparelho não tem lanterna.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([mode, camera.status, camera.torchOn]),
      builder: (context, _) {
        final visible = mode.value == DrawingMode.camera &&
            camera.status.value is CameraReady;
        if (!visible) return const SizedBox.shrink();
        final on = camera.torchOn.value;
        return IconButton(
          tooltip: on ? 'Desligar lanterna' : 'Ligar lanterna',
          isSelected: on,
          onPressed: () => _toggle(context),
          icon: const Icon(Icons.flashlight_off_outlined),
          selectedIcon: const Icon(Icons.flashlight_on),
          color: Colors.white,
        );
      },
    );
  }
}

/// Espelhar horizontalmente.
///
/// Precisa saber se a imagem está espelhada, mas o [transform] muda a cada
/// quadro de gesto. Para não reconstruir o botão 60x por segundo, ouvimos o
/// notifier "na mão" e só chamamos `setState` quando `flipped` mudar.
class _FlipButton extends StatefulWidget {
  const _FlipButton({required this.transform, required this.onPressed});

  final ValueListenable<OverlayTransform> transform;
  final VoidCallback onPressed;

  @override
  State<_FlipButton> createState() => _FlipButtonState();
}

class _FlipButtonState extends State<_FlipButton> {
  late bool _flipped = widget.transform.value.flipped;

  @override
  void initState() {
    super.initState();
    widget.transform.addListener(_onTransformChanged);
  }

  @override
  void didUpdateWidget(_FlipButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transform != widget.transform) {
      oldWidget.transform.removeListener(_onTransformChanged);
      widget.transform.addListener(_onTransformChanged);
      _flipped = widget.transform.value.flipped;
    }
  }

  @override
  void dispose() {
    // Listener esquecido = vazamento de memória e chamadas a um State morto.
    widget.transform.removeListener(_onTransformChanged);
    super.dispose();
  }

  void _onTransformChanged() {
    final flipped = widget.transform.value.flipped;
    if (flipped != _flipped) setState(() => _flipped = flipped);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Espelhar imagem',
      isSelected: _flipped,
      onPressed: widget.onPressed,
      icon: const Icon(Icons.flip),
      color: Colors.white,
      selectedIcon: const Icon(Icons.flip, color: Colors.lightBlueAccent),
    );
  }
}
