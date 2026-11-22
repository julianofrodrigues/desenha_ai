import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../image_selection/data/local_image_source.dart';
import '../models/drawing_mode.dart';
import '../models/overlay_transform.dart';
import '../services/camera_service.dart';
import '../services/screen_wake_lock.dart';
import '../widgets/camera_layers.dart';
import '../widgets/drawing_toolbar.dart';
import '../widgets/lock_button.dart';
import '../widgets/reference_overlay.dart';

/// Cria o serviço de câmera. A tela recebe uma FÁBRICA (e não o serviço
/// pronto) porque é ela quem decide quando criar e quando descartar.
typedef CameraServiceFactory = CameraService Function();

/// Tela de desenho: fundo (câmera ou mesa de luz) + imagem de referência
/// ajustável + controles.
///
/// Camadas, de baixo para cima:
/// 1. Fundo: câmera ao vivo ou cor sólida.
/// 2. Imagem de referência com gestos (tela inteira).
/// 3. Painel de status da câmera (abrindo / sem permissão).
/// 4. Controles (voltar, barra inferior). Somem quando a tela está travada.
/// 5. Botão de trava (sempre visível).
class DrawingScreen extends StatefulWidget {
  const DrawingScreen({
    super.key,
    required this.image,
    required this.cameraServiceFactory,
    required this.screenWakeLock,
  });

  final PickedImage image;
  final CameraServiceFactory cameraServiceFactory;

  /// Mantém a tela ligada enquanto esta tela estiver visível.
  final ScreenWakeLock screenWakeLock;

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

// `WidgetsBindingObserver` permite ouvir eventos do app inteiro, como "foi
// para segundo plano" e "voltou". Usamos para desligar a câmera.
class _DrawingScreenState extends State<DrawingScreen>
    with WidgetsBindingObserver {
  // Estado da tela em notifiers, e não em campos + `setState`.
  // Cada parte da UI escuta só o que precisa; ver docs/03.
  final _transform = ValueNotifier(const OverlayTransform());
  final _opacity = ValueNotifier(0.5); // 50%: dá para ver papel e referência
  final _locked = ValueNotifier(false);
  final _mode = ValueNotifier(DrawingMode.camera);
  final _lightTableColor = ValueNotifier(LightTableColor.white);

  late final CameraService _camera = widget.cameraServiceFactory();

  /// A câmera foi desligada porque o app saiu da tela (e não porque o
  /// usuário escolheu a Mesa de Luz)? Se sim, religamos ao voltar.
  bool _pausedByLifecycle = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mode.addListener(_onModeChanged);
    _camera.start();
    // Nos dois modos: na Câmera AR ninguém toca na tela enquanto desenha, e
    // na Mesa de Luz a tela É a fonte de luz.
    widget.screenWakeLock.enable();
  }

  @override
  void dispose() {
    // Ordem: primeiro paramos de OUVIR eventos, depois liberamos recursos.
    // Assim nenhum callback chega a um objeto já descartado.
    WidgetsBinding.instance.removeObserver(this);
    _mode.removeListener(_onModeChanged);
    // Ao sair da tela de desenho (voltar para a Home), a tela do aparelho
    // deve voltar a apagar normalmente. Esquecer isto deixaria a tela acesa
    // na Home para sempre, drenando a bateria.
    widget.screenWakeLock.disable();
    _camera.dispose(); // libera a câmera: essencial no Galaxy Tab A
    _transform.dispose();
    _opacity.dispose();
    _locked.dispose();
    _mode.dispose();
    _lightTableColor.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      // `hidden`: o app não está mais visível (home, outro app, tela
      // apagada). Liberamos a câmera para outros apps e para poupar bateria.
      //
      // Não usamos `inactive`: ele também acontece quando o diálogo de
      // permissão aparece ou a barra de notificações é puxada. Fechar a
      // câmera nesses casos causaria um ciclo de fechar/abrir.
      case AppLifecycleState.hidden:
        // O Android já ignora a flag com o app fora da tela, mas desligamos
        // explicitamente: o estado fica previsível e não depende desse
        // detalhe da plataforma.
        widget.screenWakeLock.disable();
        if (_mode.value == DrawingMode.camera) {
          final status = _camera.status.value;
          // Só religamos depois se estava funcionando. Se a permissão tinha
          // sido negada, não queremos pedir de novo sozinhos.
          _pausedByLifecycle =
              status is CameraReady || status is CameraStarting;
          _camera.stop();
        }
      case AppLifecycleState.resumed:
        widget.screenWakeLock.enable();
        if (_pausedByLifecycle && _mode.value == DrawingMode.camera) {
          _camera.start();
        }
        _pausedByLifecycle = false;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _onModeChanged() {
    _pausedByLifecycle = false;
    if (_mode.value == DrawingMode.camera) {
      _camera.start();
    } else {
      // Mesa de Luz: a câmera não é usada, então é desligada de verdade
      // (economiza bateria, que é um dos motivos de usar este modo).
      _camera.stop();
    }
  }

  void _resetPosition() => _transform.value = _transform.value.resetPosition();

  void _toggleFlip() => _transform.value =
      _transform.value.copyWith(flipped: !_transform.value.flipped);

  void _onBlockedPop() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Tela travada. Destrave no cadeado para sair.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    // Camadas 1 a 3. Montadas uma vez e passadas como `child` ao builder do
    // `_locked`, para que travar/destravar não as reconstrua.
    final content = Stack(
      fit: StackFit.expand,
      children: [
        _Background(
          mode: _mode,
          lightTableColor: _lightTableColor,
          camera: _camera,
        ),
        ReferenceOverlay(
          bytes: widget.image.bytes,
          transform: _transform,
          opacity: _opacity,
        ),
        _CameraStatusIfCameraMode(
          mode: _mode,
          camera: _camera,
          onUseLightTable: () => _mode.value = DrawingMode.lightTable,
        ),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: ValueListenableBuilder<bool>(
        valueListenable: _locked,
        child: content,
        builder: (context, locked, content) {
          return PopScope(
            // Travado: o gesto/botão "voltar" do Android não sai da tela.
            // A mão apoiada na borda pode disparar o gesto de voltar.
            canPop: !locked,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _onBlockedPop();
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // `IgnorePointer`: com a tela travada, NENHUM toque chega à
                // imagem ou aos botões. Só o cadeado (fora daqui) responde.
                IgnorePointer(ignoring: locked, child: content),
                if (!locked)
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: IconButton.filledTonal(
                          tooltip: 'Voltar',
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back),
                        ),
                      ),
                    ),
                  ),
                if (!locked)
                  SafeArea(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: ConstrainedBox(
                          // Em tablets, uma barra da largura da tela toda
                          // espalharia os controles demais.
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: DrawingToolbar(
                            opacity: _opacity,
                            mode: _mode,
                            lightTableColor: _lightTableColor,
                            transform: _transform,
                            camera: _camera,
                            onResetPosition: _resetPosition,
                            onToggleFlip: _toggleFlip,
                          ),
                        ),
                      ),
                    ),
                  ),
                // Canto superior direito: longe da mão que desenha (que fica
                // apoiada embaixo) e do botão voltar.
                SafeArea(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: LockButton(
                        locked: locked,
                        onLock: () => _locked.value = true,
                        onUnlock: () => _locked.value = false,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Camada 1: câmera ao vivo ou fundo sólido da mesa de luz.
class _Background extends StatelessWidget {
  const _Background({
    required this.mode,
    required this.lightTableColor,
    required this.camera,
  });

  final ValueListenable<DrawingMode> mode;
  final ValueListenable<LightTableColor> lightTableColor;
  final CameraService camera;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([mode, lightTableColor]),
      builder: (context, _) => switch (mode.value) {
        DrawingMode.camera => CameraPreviewLayer(status: camera.status),
        DrawingMode.lightTable => ColoredBox(
            color: lightTableColor.value == LightTableColor.white
                ? Colors.white
                : Colors.black,
          ),
      },
    );
  }
}

/// Camada 3: mensagens da câmera, só no Modo Câmera.
class _CameraStatusIfCameraMode extends StatelessWidget {
  const _CameraStatusIfCameraMode({
    required this.mode,
    required this.camera,
    required this.onUseLightTable,
  });

  final ValueListenable<DrawingMode> mode;
  final CameraService camera;
  final VoidCallback onUseLightTable;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DrawingMode>(
      valueListenable: mode,
      builder: (context, mode, _) => mode == DrawingMode.camera
          ? CameraStatusPanel(
              status: camera.status,
              onUseLightTable: onUseLightTable,
              onRetry: camera.start,
            )
          : const SizedBox.shrink(),
    );
  }
}
