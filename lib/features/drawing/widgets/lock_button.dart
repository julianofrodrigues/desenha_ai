import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Botão de trava da tela.
///
/// - Destravado: um toque TRAVA (precisa ser rápido de ativar).
/// - Travado: é preciso SEGURAR por [holdDuration] ou dar um TOQUE DUPLO para
///   destravar. Um toque simples (ex.: a mão encostando sem querer) não faz
///   nada. Um anel de progresso mostra quanto falta.
class LockButton extends StatefulWidget {
  const LockButton({
    super.key,
    required this.locked,
    required this.onLock,
    required this.onUnlock,
  });

  static const holdDuration = Duration(milliseconds: 1500);

  final bool locked;
  final VoidCallback onLock;
  final VoidCallback onUnlock;

  @override
  State<LockButton> createState() => _LockButtonState();
}

// `SingleTickerProviderStateMixin` fornece o "relógio" (Ticker) que move o
// AnimationController a cada quadro, e o pausa quando o widget sai da tela.
class _LockButtonState extends State<LockButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: LockButton.holdDuration,
  )..addStatusListener(_onHoldStatus);

  @override
  void didUpdateWidget(LockButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Destravou por outro caminho (ex.: toque duplo): zera o anel.
    if (!widget.locked) _hold.reset();
  }

  @override
  void dispose() {
    // Um AnimationController esquecido continua consumindo o Ticker e a
    // memória. Sempre descarte no `dispose`.
    _hold.dispose();
    super.dispose();
  }

  void _onHoldStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _unlock();
  }

  void _unlock() {
    _hold.reset();
    // Vibração curta: confirma a ação sem o usuário precisar olhar.
    HapticFeedback.mediumImpact();
    widget.onUnlock();
  }

  void _lock() {
    HapticFeedback.mediumImpact();
    widget.onLock();
  }

  void _startHold() {
    if (widget.locked) _hold.forward();
  }

  void _cancelHold() {
    // Soltou antes do tempo: o anel volta suavemente, mostrando que não
    // destravou.
    if (_hold.isAnimating || _hold.value > 0) _hold.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final locked = widget.locked;

    // `Listener` recebe os toques "crus" (dedo desceu/subiu) sem competir com
    // o `GestureDetector`. Usamos ele para o "segurar", e o GestureDetector
    // para toque simples / toque duplo.
    return Listener(
      onPointerDown: (_) => _startHold(),
      onPointerUp: (_) => _cancelHold(),
      onPointerCancel: (_) => _cancelHold(),
      child: GestureDetector(
        // Com `onTap` e `onDoubleTap` juntos, o Flutter espera para saber se
        // vem um segundo toque, atrasando o toque simples. Por isso cada
        // estado registra só o gesto que usa.
        onTap: locked ? null : _lock,
        onDoubleTap: locked ? _unlock : null,
        child: Semantics(
          button: true,
          label: locked
              ? 'Tela travada. Segure ou toque duas vezes para destravar.'
              : 'Travar tela',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Material(
                      shape: const CircleBorder(),
                      color: locked
                          ? colors.primary
                          : Colors.black.withValues(alpha: 0.55),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: Icon(
                          locked ? Icons.lock : Icons.lock_open,
                          color: locked ? colors.onPrimary : Colors.white,
                        ),
                      ),
                    ),
                    // Só o anel escuta a animação: o resto do botão não é
                    // reconstruído a cada quadro.
                    AnimatedBuilder(
                      animation: _hold,
                      builder: (context, _) => _hold.value == 0
                          ? const SizedBox.shrink()
                          : SizedBox.expand(
                              child: CircularProgressIndicator(
                                value: _hold.value,
                                strokeWidth: 4,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              if (locked) ...[
                const SizedBox(height: 6),
                const _Hint('Segure ou toque 2x\npara destravar'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }
}
