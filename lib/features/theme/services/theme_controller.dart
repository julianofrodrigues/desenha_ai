import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'theme_preference_store.dart';

/// Guarda e alterna o modo de tema do app (Fase 6, Etapa 6A).
///
/// - Sem preferência salva: [ThemeMode.system] (segue o aparelho).
/// - Depois do primeiro toque no botão: [ThemeMode.light] ou
///   [ThemeMode.dark], salvo no disco e mantido nas próximas aberturas.
///
/// Expõe o modo como [ValueListenable]: só o `MaterialApp` escuta, e o
/// resto da tela não precisa saber que o tema existe.
class ThemeController {
  ThemeController({
    required this.store,
    ThemeMode initialMode = ThemeMode.system,
  }) : _mode = ValueNotifier(initialMode);

  /// Lê a preferência salva ANTES do `runApp` (ver `main.dart`). Assim o
  /// primeiro quadro já sai no tema certo, sem "piscar" do claro para o
  /// escuro ao abrir.
  static Future<ThemeController> load(ThemePreferenceStore store) async {
    final saved = await store.load();
    return ThemeController(store: store, initialMode: _modeFor(saved));
  }

  /// Onde a escolha é gravada (arquivo no app, memória nos testes).
  final ThemePreferenceStore store;
  final ValueNotifier<ThemeMode> _mode;

  ValueListenable<ThemeMode> get mode => _mode;

  /// Alterna entre claro e escuro e salva a escolha.
  ///
  /// [current] é o brilho que o usuário está VENDO agora. Ele é necessário
  /// no primeiro toque, quando o modo ainda é "sistema": se o aparelho está
  /// escuro, o toque precisa ir para o CLARO (e vice-versa).
  ///
  /// A tela muda na hora; a gravação acontece em seguida. Se gravar falhar
  /// (ex.: armazenamento cheio), o tema continua trocado nesta sessão, só
  /// não é lembrado na próxima.
  Future<void> toggle(Brightness current) async {
    final next =
        current == Brightness.dark ? Brightness.light : Brightness.dark;
    _mode.value = _modeFor(next);
    try {
      await store.save(next);
    } catch (error) {
      debugPrint('Não foi possível salvar o tema: $error');
    }
  }

  static ThemeMode _modeFor(Brightness? brightness) => switch (brightness) {
        Brightness.light => ThemeMode.light,
        Brightness.dark => ThemeMode.dark,
        null => ThemeMode.system,
      };

  /// Quem cria, descarta (no app, o `main`, que vive o app inteiro; nos
  /// testes, cada teste).
  void dispose() => _mode.dispose();
}
