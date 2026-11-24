import 'package:material_ui/material_ui.dart';

import '../app_palette.dart';
import '../services/theme_controller.dart';

/// Botão ÚNICO que alterna claro/escuro, com transição de sol ↔ lua
/// (Fase 6, Etapa 6A).
///
/// Visual: no modo claro aparece o sol; no escuro, a lua. Ao trocar, o
/// ícone que sai gira e encolhe enquanto o que entra gira e cresce, num
/// movimento de "meia volta".
///
/// Desempenho (Galaxy Tab A):
/// - Usa `RotationTransition`, `ScaleTransition` e `FadeTransition`. Essas
///   transições ligam a animação direto na camada de pintura: a cada quadro
///   NÃO há `build`, nem deste botão nem do resto da tela.
/// - Dois ícones de fonte (sem imagens, sem `CustomPainter`).
/// - 350 ms: curto para não atrasar o toque e longo para ser percebido.
class ThemeToggleButton extends StatefulWidget {
  const ThemeToggleButton({super.key, required this.controller});

  final ThemeController controller;

  static const duration = Duration(milliseconds: 350);

  /// Área de toque do botão. Etapa 6C: 56 dp (era 48 dp, o padrão do
  /// `IconButton`), mais confortável para o polegar no RedMagic e para
  /// acertar sem olhar no Tab A apoiado na mesa.
  static const double size = 56;

  /// Tamanho do sol/da lua. Etapa 6C: 30 dp (era 24 dp).
  static const double iconSize = 30;

  @override
  State<ThemeToggleButton> createState() => _ThemeToggleButtonState();
}

class _ThemeToggleButtonState extends State<ThemeToggleButton>
    with SingleTickerProviderStateMixin {
  /// 0 = sol (claro), 1 = lua (escuro).
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: ThemeToggleButton.duration,
  );

  late final Animation<double> _curved = CurvedAnimation(
    parent: _animation,
    curve: Curves.easeOutBack, // um pequeno "quique" no fim
    reverseCurve: Curves.easeInBack,
  );

  /// Sol: visível em 0, some em 1. Lua: o contrário.
  late final Animation<double> _sunOpacity =
      Tween<double>(begin: 1, end: 0).animate(_animation);
  late final Animation<double> _moonOpacity = _animation;

  late final Animation<double> _sunScale =
      Tween<double>(begin: 1, end: 0.3).animate(_curved);
  late final Animation<double> _moonScale =
      Tween<double>(begin: 0.3, end: 1).animate(_curved);

  // `RotationTransition` trabalha em VOLTAS (1.0 = 360°).
  late final Animation<double> _sunTurns =
      Tween<double>(begin: 0, end: 0.5).animate(_curved);
  late final Animation<double> _moonTurns =
      Tween<double>(begin: -0.5, end: 0).animate(_curved);

  bool _initialized = false;
  bool _isDark = false;

  @override
  void initState() {
    super.initState();
    // Escuta o MODO escolhido (e não o `Theme`). Motivo: o `MaterialApp`
    // faz a transição entre temas em 250 ms e só troca o brilho NA METADE
    // dela. Seguindo o `Theme`, o sol/lua começaria a girar ~125 ms depois
    // do toque (parece travado) e os quadros intermediários poderiam até
    // inverter a animação. Seguindo o modo, a resposta é imediata.
    widget.controller.mode.addListener(_sync);
  }

  @override
  void didUpdateWidget(ThemeToggleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.mode.removeListener(_sync);
      widget.controller.mode.addListener(_sync);
      _sync();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Chamado quando o tema do SISTEMA muda (dependemos do `MediaQuery`).
    // Importa no modo "sistema": se o aparelho escurecer, a lua aparece.
    _sync();
  }

  /// O que o usuário vai ver: a escolha manual, ou o tema do sistema se ele
  /// ainda não escolheu (a mesma regra do `MaterialApp`).
  bool get _targetIsDark => switch (widget.controller.mode.value) {
        ThemeMode.dark => true,
        ThemeMode.light => false,
        ThemeMode.system =>
          MediaQuery.platformBrightnessOf(context) == Brightness.dark,
      };

  void _sync() {
    final isDark = _targetIsDark;
    if (!_initialized) {
      // Primeira vez: posiciona sem animar (o app não "anima" ao abrir).
      _initialized = true;
      _isDark = isDark;
      _animation.value = isDark ? 1 : 0;
      return;
    }
    if (isDark == _isDark) return;
    // `setState` só para o texto da dica; os ícones são movidos pelas
    // transições, sem `build`.
    setState(() => _isDark = isDark);
    isDark ? _animation.forward() : _animation.reverse();
  }

  @override
  void dispose() {
    // Ouvinte esquecido = chamadas a um State morto.
    widget.controller.mode.removeListener(_sync);
    // Um AnimationController não descartado continua preso ao Ticker.
    // Descartar aqui também é o que permite sair da tela NO MEIO da
    // animação sem vazamento.
    _animation.dispose();
    super.dispose();
  }

  void _toggle() {
    widget.controller
        .toggle(_isDark ? Brightness.dark : Brightness.light);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      // O texto diz o que o toque VAI fazer, que é o mais útil para o leitor
      // de tela e para a dica ao segurar o dedo.
      tooltip: _isDark ? 'Ativar modo claro' : 'Ativar modo escuro',
      onPressed: _toggle,
      // Etapa 6C: maior, para o toque ficar mais confortável (o padrão do
      // IconButton é um ícone de 24 dp numa área de 48 dp).
      iconSize: ThemeToggleButton.iconSize,
      constraints: const BoxConstraints.tightFor(
        width: ThemeToggleButton.size,
        height: ThemeToggleButton.size,
      ),
      icon: SizedBox.square(
        dimension: ThemeToggleButton.iconSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _AnimatedIcon(
              key: const ValueKey('sun'),
              icon: Icons.light_mode,
              color: AppPalette.sun,
              opacity: _sunOpacity,
              scale: _sunScale,
              turns: _sunTurns,
            ),
            _AnimatedIcon(
              key: const ValueKey('moon'),
              icon: Icons.dark_mode,
              color: AppPalette.moon,
              opacity: _moonOpacity,
              scale: _moonScale,
              turns: _moonTurns,
            ),
          ],
        ),
      ),
    );
  }
}

/// Um ícone que gira, muda de tamanho e aparece/some conforme as animações.
class _AnimatedIcon extends StatelessWidget {
  const _AnimatedIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.opacity,
    required this.scale,
    required this.turns,
  });

  final IconData icon;
  final Color color;
  final Animation<double> opacity;
  final Animation<double> scale;
  final Animation<double> turns;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: opacity,
      child: ScaleTransition(
        scale: scale,
        child: RotationTransition(
          turns: turns,
          child: Icon(icon, color: color),
        ),
      ),
    );
  }
}
