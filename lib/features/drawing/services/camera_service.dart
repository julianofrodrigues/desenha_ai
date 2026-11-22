// Serviço de câmera: esconde o plugin `camera` atrás de uma interface.
//
// Por que um serviço, e não usar o `CameraController` direto na tela?
// - O ciclo de vida da câmera (pedir permissão, abrir, fechar, reabrir ao
//   voltar do segundo plano, tratar erros) é delicado e ficaria misturado com
//   código de UI.
// - A tela depende só de [CameraService]. Nos testes, usamos uma versão falsa
//   que não precisa de câmera nem de permissão.
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// Estados da câmera
// ---------------------------------------------------------------------------

/// Em que situação a câmera está. `sealed` garante que a UI trate todos.
sealed class CameraStatus {
  const CameraStatus();
}

/// Desligada (Modo Mesa de Luz, app em segundo plano ou ainda não iniciada).
final class CameraOff extends CameraStatus {
  const CameraOff();
}

/// Pedindo permissão / abrindo a câmera.
final class CameraStarting extends CameraStatus {
  const CameraStarting();
}

/// Pronta: a imagem ao vivo pode ser exibida com [controller].
final class CameraReady extends CameraStatus {
  const CameraReady(this.controller);
  final CameraController controller;
}

/// O usuário negou a permissão da câmera.
final class CameraPermissionDenied extends CameraStatus {
  const CameraPermissionDenied();
}

/// Outro problema: aparelho sem câmera, câmera em uso por outro app etc.
final class CameraUnavailable extends CameraStatus {
  const CameraUnavailable(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// Contrato
// ---------------------------------------------------------------------------

/// O que a tela de desenho precisa de uma câmera.
///
/// Expõe o estado como [ValueListenable] (só leitura): a tela pode ouvir,
/// mas só o serviço altera.
abstract interface class CameraService {
  ValueListenable<CameraStatus> get status;

  /// Lanterna ligada? Volta a `false` sempre que a câmera é desligada.
  ValueListenable<bool> get torchOn;

  /// Liga a câmera traseira (pede permissão na primeira vez).
  Future<void> start();

  /// Desliga a câmera e libera o hardware.
  Future<void> stop();

  /// Liga/desliga a lanterna. Devolve `false` se o aparelho não suportar.
  Future<bool> setTorch(bool on);

  /// Libera tudo. Depois disso o serviço não pode mais ser usado.
  void dispose();
}

// ---------------------------------------------------------------------------
// Implementação real
// ---------------------------------------------------------------------------

/// Implementação com o plugin oficial `camera` (CameraX no Android).
class PluginCameraService implements CameraService {
  final _status = ValueNotifier<CameraStatus>(const CameraOff());
  final _torchOn = ValueNotifier<bool>(false);

  CameraController? _controller;

  /// "Número da tentativa" atual. Cada `start`/`stop` incrementa.
  ///
  /// Por quê? Abrir a câmera demora (centenas de ms). Se o usuário trocar de
  /// modo rapidamente (Câmera -> Mesa de Luz -> Câmera), uma abertura antiga
  /// pode terminar DEPOIS de um `stop`. Comparando a geração, sabemos que o
  /// resultado é obsoleto e fechamos aquela câmera em vez de exibi-la.
  int _generation = 0;
  bool _disposed = false;

  @override
  ValueListenable<CameraStatus> get status => _status;

  @override
  ValueListenable<bool> get torchOn => _torchOn;

  @override
  Future<void> start() async {
    final current = _status.value;
    if (_disposed || current is CameraReady || current is CameraStarting) {
      return;
    }

    final generation = ++_generation;
    _status.value = const CameraStarting();

    CameraController? controller;
    try {
      final cameras = await availableCameras();
      final back = cameras
              .where((c) => c.lensDirection == CameraLensDirection.back)
              .firstOrNull ??
          cameras.firstOrNull; // tablets simples às vezes só têm uma câmera

      if (back == null) {
        if (generation == _generation) {
          _status.value =
              const CameraUnavailable('Nenhuma câmera encontrada no aparelho.');
        }
        return;
      }

      controller = CameraController(
        back,
        // `high` (~720p) é nítido o bastante para ver o papel e leve para o
        // Galaxy Tab A. `max` gastaria mais memória, bateria e esquentaria o
        // aparelho sem ganho visível atrás de uma imagem semitransparente.
        ResolutionPreset.high,
        // Não gravamos vídeo. Sem áudio, o plugin nem pede a permissão de
        // microfone.
        enableAudio: false,
      );

      // `initialize` também pede a permissão da câmera, se necessário.
      await controller.initialize();

      // Chegou um `stop` (ou `dispose`) enquanto abríamos? Descarta.
      if (generation != _generation || _disposed) {
        await controller.dispose();
        return;
      }

      _controller = controller;
      _status.value = CameraReady(controller);
    } on CameraException catch (e) {
      await controller?.dispose();
      if (generation != _generation || _disposed) return;
      debugPrint('Erro de câmera: ${e.code} ${e.description}');
      _status.value = _isPermissionError(e.code)
          ? const CameraPermissionDenied()
          : const CameraUnavailable(
              'Não foi possível abrir a câmera. Ela pode estar em uso por '
              'outro app.',
            );
    }
  }

  /// Códigos que o plugin usa quando a permissão é negada. O primeiro é o
  /// do Android (CameraX); os outros vêm do iOS e foram mantidos para o
  /// código não quebrar se um dia o app for portado.
  static bool _isPermissionError(String code) => const {
        'CameraAccessDenied',
        'CameraAccessDeniedWithoutPrompt',
        'CameraAccessRestricted',
      }.contains(code);

  @override
  Future<void> stop() async {
    _generation++; // invalida qualquer `start` em andamento
    final controller = _controller;
    _controller = null;
    _torchOn.value = false;

    // Primeiro avisamos a UI (que deixa de desenhar o preview), depois
    // liberamos o hardware. Na ordem inversa, a UI poderia tentar desenhar
    // um controller já descartado.
    if (!_disposed) _status.value = const CameraOff();
    await controller?.dispose();
  }

  @override
  Future<bool> setTorch(bool on) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return false;
    try {
      await controller.setFlashMode(on ? FlashMode.torch : FlashMode.off);
      if (!_disposed) _torchOn.value = on;
      return true;
    } on CameraException catch (e) {
      // Muitos tablets (inclusive alguns Galaxy Tab A) não têm flash.
      debugPrint('Lanterna indisponível: ${e.code}');
      return false;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    // `stop` primeiro (ainda pode atualizar os notifiers), depois marcamos
    // como descartado e liberamos os notifiers.
    stop();
    _disposed = true;
    _status.dispose();
    _torchOn.dispose();
  }
}
