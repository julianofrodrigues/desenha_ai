// Implementações falsas dos serviços, compartilhadas entre os testes.
import 'package:camera/camera.dart';
import 'package:desenha_ai/features/drawing/services/camera_service.dart';
import 'package:desenha_ai/features/drawing/services/screen_wake_lock.dart';
import 'package:desenha_ai/features/image_selection/data/local_image_source.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fonte de imagens falsa: cada chamada a `pickImage` executa [onPick].
class FakeImageSource implements LocalImageSource {
  FakeImageSource(this.onPick);

  Future<PickedImage?> Function() onPick;

  @override
  Future<PickedImage?> pickImage() => onPick();
}

/// Câmera falsa: `start` vai direto para o estado escolhido em [onStart],
/// sem hardware nem permissão. Conta as chamadas para os testes verificarem
/// o ciclo de vida.
class FakeCameraService implements CameraService {
  FakeCameraService({CameraStatus Function()? onStart, this.torchSupported = false})
      : onStart = onStart ?? (() => const CameraOff());

  CameraStatus Function() onStart;
  final bool torchSupported;

  final _status = ValueNotifier<CameraStatus>(const CameraOff());
  final _torchOn = ValueNotifier<bool>(false);

  int startCalls = 0;
  int stopCalls = 0;
  bool disposed = false;

  @override
  ValueListenable<CameraStatus> get status => _status;

  @override
  ValueListenable<bool> get torchOn => _torchOn;

  @override
  Future<void> start() async {
    startCalls++;
    _status.value = onStart();
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _torchOn.value = false;
    _status.value = const CameraOff();
  }

  @override
  Future<bool> setTorch(bool on) async {
    if (!torchSupported) return false;
    _torchOn.value = on;
    return true;
  }

  @override
  void dispose() {
    disposed = true;
    _status.dispose();
    _torchOn.dispose();
  }
}

/// Wakelock falso: guarda se está ligado e quantas vezes foi chamado.
class FakeScreenWakeLock implements ScreenWakeLock {
  bool enabled = false;
  int enableCalls = 0;
  int disableCalls = 0;

  @override
  Future<void> enable() async {
    enableCalls++;
    enabled = true;
  }

  @override
  Future<void> disable() async {
    disableCalls++;
    enabled = false;
  }
}

/// Estado "câmera pronta" para testes. Criar um `CameraController` não toca
/// no hardware; só `initialize()` faria isso, e não chamamos.
CameraReady fakeReadyStatus() => CameraReady(
      CameraController(
        const CameraDescription(
          name: 'fake',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 90,
        ),
        ResolutionPreset.high,
        enableAudio: false,
      ),
    );

/// PNG válido de 1x1 pixel.
final pngBytes = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Avança o tempo o suficiente para terminar transições (fade, troca de
/// rota). Não usamos `pumpAndSettle` porque indicadores de progresso e a
/// decodificação de imagem nunca "assentam" no relógio falso dos testes.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}
