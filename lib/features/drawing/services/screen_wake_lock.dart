// Mantém a tela ligada enquanto o usuário desenha.
//
// Sem isso, o Android apaga a tela depois do tempo de descanso (30 s a
// alguns minutos) porque, enquanto a pessoa desenha no papel, ninguém toca
// na tela. No Modo Mesa de Luz isso é especialmente ruim: a "luz" apaga no
// meio do traço.
//
// Como no serviço de câmera, a tela depende só da interface. Nos testes, uma
// versão falsa conta as chamadas sem falar com o Android.
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Liga/desliga o "não apagar a tela".
abstract interface class ScreenWakeLock {
  Future<void> enable();
  Future<void> disable();
}

/// Implementação com o pacote `wakelock_plus`.
///
/// No Android ele liga a flag `FLAG_KEEP_SCREEN_ON` na janela do app. Não é
/// um "wake lock" de CPU: só impede a tela de apagar enquanto o app está
/// visível, e não exige permissão no AndroidManifest (ver docs/03).
class WakelockPlusScreenWakeLock implements ScreenWakeLock {
  const WakelockPlusScreenWakeLock();

  @override
  Future<void> enable() => _run(WakelockPlus.enable, 'ligar');

  @override
  Future<void> disable() => _run(WakelockPlus.disable, 'desligar');

  /// Falhar em manter a tela ligada é incômodo, mas não pode derrubar a tela
  /// de desenho. Por isso o erro é só registrado.
  static Future<void> _run(Future<void> Function() action, String what) async {
    try {
      await action();
    } catch (error) {
      debugPrint('Não foi possível $what o wakelock: $error');
    }
  }
}
