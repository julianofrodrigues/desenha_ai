// Fase 6 (Etapa 6A): tema claro/escuro, botão único de sol/lua e
// persistência offline da escolha.
import 'dart:io';

import 'package:desenha_ai/app.dart';
import 'package:desenha_ai/features/theme/app_palette.dart';
import 'package:desenha_ai/features/theme/app_theme.dart';
import 'package:desenha_ai/features/theme/services/theme_controller.dart';
import 'package:desenha_ai/features/theme/services/theme_preference_store.dart';
import 'package:desenha_ai/features/theme/widgets/theme_toggle_button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../fakes.dart';

/// Monta o app inteiro com um controlador de tema dado.
Future<void> _pumpApp(WidgetTester tester, ThemeController theme) async {
  await tester.pumpWidget(
    DesenhaAiApp(
      imageSource: FakeImageSource(() async => null),
      projectRepository: FakeProjectRepository(),
      categoryRepository: FakeCategoryRepository(),
      cameraServiceFactory: FakeCameraService.new,
      screenWakeLock: FakeScreenWakeLock(),
      themeController: theme,
    ),
  );
  await tester.pump();
}

/// Brilho que a Home está mostrando DE FATO (já resolvido o modo sistema).
Brightness _visibleBrightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

/// Simula o tema do sistema operacional.
void _setSystemBrightness(WidgetTester tester, Brightness brightness) {
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

/// Espera a animação do botão e o "fade" do tema terminarem.
Future<void> _finishAnimations(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Opacidade atual do ícone de sol ('sun') ou de lua ('moon').
double _opacityOf(WidgetTester tester, String key) => tester
    .widget<FadeTransition>(
      find
          .descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

void main() {
  group('paleta', () {
    test('modo claro e escuro têm a identidade própria do app', () {
      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.dark.brightness, Brightness.dark);
      expect(AppTheme.light.colorScheme.primary, AppPalette.violet);
      expect(AppTheme.dark.colorScheme.primary, AppPalette.violetLight);
      expect(AppTheme.light.scaffoldBackgroundColor, AppPalette.lightBackground);
      expect(AppTheme.dark.scaffoldBackgroundColor, AppPalette.darkBackground);
    });

    test('texto tem bom contraste com o fundo nos dois modos', () {
      // Razão de contraste do WCAG: 4,5 é o mínimo para texto comum.
      double contrast(Color a, Color b) {
        final la = a.computeLuminance(), lb = b.computeLuminance();
        final (hi, lo) = la > lb ? (la, lb) : (lb, la);
        return (hi + 0.05) / (lo + 0.05);
      }

      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final c = theme.colorScheme;
        expect(contrast(c.onSurface, c.surface), greaterThan(7));
        expect(contrast(c.onSurfaceVariant, c.surface), greaterThan(4.5));
        expect(contrast(c.onPrimary, c.primary), greaterThan(4.5));
      }
    });
  });

  group('FileThemePreferenceStore', () {
    late Directory temp;
    late File file;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('desenha_ai_theme');
      file = File('${temp.path}${Platform.pathSeparator}preferences.json');
    });

    tearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    test('sem arquivo = nenhuma escolha (segue o sistema)', () async {
      expect(await FileThemePreferenceStore(file: file).load(), isNull);
    });

    test('grava e lê de volta, mesmo com um "app" novo', () async {
      await FileThemePreferenceStore(file: file).save(Brightness.dark);
      expect(
        await FileThemePreferenceStore(file: file).load(),
        Brightness.dark,
      );
    });

    test('várias gravações seguidas: a última vence', () async {
      final store = FileThemePreferenceStore(file: file);
      await Future.wait([
        store.save(Brightness.dark),
        store.save(Brightness.light),
        store.save(Brightness.dark),
      ]);
      expect(await store.load(), Brightness.dark);
    });

    test('arquivo corrompido ou valor desconhecido = segue o sistema',
        () async {
      file.writeAsStringSync('{lixo');
      expect(await FileThemePreferenceStore(file: file).load(), isNull);
      file.writeAsStringSync('{"theme": "roxo"}');
      expect(await FileThemePreferenceStore(file: file).load(), isNull);
    });
  });

  group('ThemeController', () {
    test('sem preferência salva começa no modo do sistema', () async {
      final c = await ThemeController.load(FakeThemePreferenceStore());
      addTearDown(c.dispose);
      expect(c.mode.value, ThemeMode.system);
    });

    test('com preferência salva começa nela', () async {
      final c = await ThemeController.load(
        FakeThemePreferenceStore(saved: Brightness.light),
      );
      addTearDown(c.dispose);
      expect(c.mode.value, ThemeMode.light);
    });

    test('alterna a partir do que está visível e salva', () async {
      final store = FakeThemePreferenceStore();
      final c = ThemeController(store: store);
      addTearDown(c.dispose);

      // Modo sistema mostrando escuro: o primeiro toque vai para o CLARO.
      await c.toggle(Brightness.dark);
      expect(c.mode.value, ThemeMode.light);
      expect(store.saved, Brightness.light);

      await c.toggle(Brightness.light);
      expect(c.mode.value, ThemeMode.dark);
      expect(store.saved, Brightness.dark);
    });

    test('falha ao salvar não impede a troca nesta sessão', () async {
      final c =
          ThemeController(store: FakeThemePreferenceStore(failOnSave: true));
      addTearDown(c.dispose);
      await c.toggle(Brightness.light);
      expect(c.mode.value, ThemeMode.dark);
    });
  });

  group('app e botão de sol/lua', () {
    testWidgets('1ª execução com o sistema ESCURO abre no escuro, com a lua',
        (tester) async {
      _setSystemBrightness(tester, Brightness.dark);
      final theme = await ThemeController.load(FakeThemePreferenceStore());
      addTearDown(theme.dispose);
      await _pumpApp(tester, theme);

      expect(_visibleBrightness(tester), Brightness.dark);
      expect(find.byTooltip('Ativar modo claro'), findsOneWidget);
      expect(_opacityOf(tester, 'moon'), 1);
      expect(_opacityOf(tester, 'sun'), 0);
    });

    testWidgets('1ª execução com o sistema CLARO abre no claro, com o sol',
        (tester) async {
      _setSystemBrightness(tester, Brightness.light);
      final theme = await ThemeController.load(FakeThemePreferenceStore());
      addTearDown(theme.dispose);
      await _pumpApp(tester, theme);

      expect(_visibleBrightness(tester), Brightness.light);
      expect(find.byTooltip('Ativar modo escuro'), findsOneWidget);
      expect(_opacityOf(tester, 'sun'), 1);
    });

    testWidgets('o botão fica no canto superior direito e é único',
        (tester) async {
      final theme = fakeThemeController();
      addTearDown(theme.dispose);
      await _pumpApp(tester, theme);

      expect(find.byType(ThemeToggleButton), findsOneWidget);
      final button = tester.getRect(find.byType(ThemeToggleButton));
      final screen = tester.getRect(find.byType(Scaffold).first);
      expect(button.top, lessThan(100));
      expect(screen.right - button.right, lessThan(16));
    });

    testWidgets('cada toque alterna claro ↔ escuro, animando sol e lua',
        (tester) async {
      _setSystemBrightness(tester, Brightness.light);
      final store = FakeThemePreferenceStore();
      final theme = ThemeController(store: store);
      addTearDown(theme.dispose);
      await _pumpApp(tester, theme);

      await tester.tap(find.byType(ThemeToggleButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      // No meio da animação, os dois ícones estão parcialmente visíveis.
      final midMoon = _opacityOf(tester, 'moon');
      expect(midMoon, greaterThan(0));
      expect(midMoon, lessThan(1));

      await _finishAnimations(tester);
      expect(_visibleBrightness(tester), Brightness.dark);
      expect(_opacityOf(tester, 'moon'), 1);
      expect(find.byTooltip('Ativar modo claro'), findsOneWidget);

      await tester.tap(find.byType(ThemeToggleButton));
      await _finishAnimations(tester);
      expect(_visibleBrightness(tester), Brightness.light);
      expect(_opacityOf(tester, 'sun'), 1);
      expect(store.saves, 2);
      expect(store.saved, Brightness.light);
    });

    testWidgets('a escolha manual vence o sistema e sobrevive ao reinício',
        (tester) async {
      _setSystemBrightness(tester, Brightness.dark);
      final store = FakeThemePreferenceStore();

      // 1ª abertura: segue o sistema (escuro); o usuário troca para claro.
      final first = await ThemeController.load(store);
      await _pumpApp(tester, first);
      await tester.tap(find.byType(ThemeToggleButton));
      await _finishAnimations(tester);
      expect(_visibleBrightness(tester), Brightness.light);

      // "Fecha o app": a árvore inteira é descartada.
      await tester.pumpWidget(const SizedBox());
      first.dispose();

      // 2ª abertura: lê do "disco". O sistema continua escuro, mas vale a
      // escolha salva.
      final second = await ThemeController.load(store);
      addTearDown(second.dispose);
      await _pumpApp(tester, second);
      expect(_visibleBrightness(tester), Brightness.light);

      // Mudar o tema do sistema não muda nada depois da escolha manual.
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await _finishAnimations(tester);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await _finishAnimations(tester);
      expect(_visibleBrightness(tester), Brightness.light);
    });

    testWidgets('trocar o tema não recria a Home (busca continua)',
        (tester) async {
      final theme = fakeThemeController();
      addTearDown(theme.dispose);
      await tester.pumpWidget(
        DesenhaAiApp(
          imageSource: FakeImageSource(() async => null),
          projectRepository:
              FakeProjectRepository(initial: [sampleProject(name: 'gato.png')]),
          categoryRepository: FakeCategoryRepository(),
          cameraServiceFactory: FakeCameraService.new,
          screenWakeLock: FakeScreenWakeLock(),
          themeController: theme,
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'gato');
      await tester.pump();

      await tester.tap(find.byType(ThemeToggleButton));
      await _finishAnimations(tester);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'gato');
    });

    testWidgets('sair da tela NO MEIO da animação não vaza o controller',
        (tester) async {
      final theme = fakeThemeController();
      addTearDown(theme.dispose);
      await _pumpApp(tester, theme);

      await tester.tap(find.byType(ThemeToggleButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100)); // animando

      // Se o AnimationController não fosse descartado, o Flutter acusaria
      // "disposed with an active Ticker" aqui.
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
      expect(find.byType(ThemeToggleButton), findsNothing);
    });
  });
}
