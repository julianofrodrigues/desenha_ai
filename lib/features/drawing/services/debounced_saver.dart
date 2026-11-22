import 'dart:async';

import 'package:flutter/foundation.dart';

/// Salva "um pouco depois da última mudança" (debounce).
///
/// Durante um gesto de arrastar/zoom, o estado muda ~60 vezes por segundo.
/// Gravar em disco a cada mudança travaria a UI no Galaxy Tab A (I/O é lento)
/// e gastaria a memória flash à toa. Com debounce:
///
/// ```
/// mudanças:  x x x x x x x x            x
/// gravações:                  [grava]     ... [grava]
///            |<-- gesto -->|<- delay ->|
/// ```
///
/// Cada [schedule] reinicia o relógio; só gravamos quando o usuário fica
/// [delay] sem mexer.
///
/// Garantias:
/// - Gravações nunca se sobrepõem: cada uma espera a anterior terminar (uma
///   fila). Assim um arquivo antigo nunca sobrescreve um mais novo.
/// - O [snapshot] é tirado na hora em que a gravação é disparada, de forma
///   síncrona. Mesmo que a tela seja descartada logo depois, o valor salvo é
///   o último que o usuário viu.
class DebouncedSaver<T> {
  DebouncedSaver({
    required this.delay,
    required this.snapshot,
    required this.write,
  });

  final Duration delay;

  /// Lê o estado atual (síncrono e barato).
  final T Function() snapshot;

  /// Grava o estado (assíncrono, pode ser lento).
  final Future<void> Function(T value) write;

  Timer? _timer;
  bool _dirty = false;
  bool _disposed = false;
  Future<void> _queue = Future.value();

  /// Avisa que algo mudou. A gravação acontece [delay] depois da ÚLTIMA
  /// chamada.
  void schedule() {
    if (_disposed) return;
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(delay, flush);
  }

  /// Grava AGORA se houver mudança pendente (ex.: app indo para segundo
  /// plano, onde o Android pode matar o processo sem aviso).
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    if (!_dirty) return _queue;
    _dirty = false;

    final value = snapshot();
    _queue = _queue.then((_) => write(value)).catchError((Object error) {
      // Falhar ao salvar não pode derrubar a tela de desenho. Registramos e
      // seguimos; a próxima mudança tenta de novo.
      debugPrint('Falha ao salvar automaticamente: $error');
    });
    return _queue;
  }

  /// Grava o que estiver pendente e para de aceitar novos agendamentos.
  /// Também cancela o Timer: um Timer esquecido mantém a tela na memória.
  Future<void> dispose() {
    final pending = flush();
    _disposed = true;
    return pending;
  }
}
