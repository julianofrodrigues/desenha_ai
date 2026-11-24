// Fase 6 (Etapa 6B): Home sem header, botão de sol/lua flutuando no canto
// superior direito, botões lado a lado sem imagem e marca "Desenha A.I"
// desenhada.
import 'package:desenha_ai/app.dart';
import 'package:desenha_ai/features/image_selection/presentation/widgets/home_status_views.dart';
import 'package:desenha_ai/features/projects/screens/categories_screen.dart';
import 'package:desenha_ai/features/projects/screens/category_filter_screen.dart';
import 'package:desenha_ai/features/projects/widgets/category_badge.dart';
import 'package:desenha_ai/features/projects/widgets/category_filter_bar.dart';
import 'package:desenha_ai/features/projects/widgets/project_history_list.dart';
import 'package:desenha_ai/features/projects/widgets/project_history_tile.dart';
import 'package:desenha_ai/features/projects/widgets/project_search_field.dart';
import 'package:desenha_ai/features/theme/app_theme.dart';
import 'package:desenha_ai/features/theme/services/theme_controller.dart';
import 'package:desenha_ai/features/theme/widgets/desenha_ai_logo.dart';
import 'package:desenha_ai/features/theme/widgets/theme_toggle_button.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../fakes.dart';

Future<ThemeController> _pumpHome(
  WidgetTester tester, {
  bool withProjects = false,
}) async {
  final theme = ThemeController(store: FakeThemePreferenceStore());
  addTearDown(theme.dispose);
  await tester.pumpWidget(
    DesenhaAiApp(
      imageSource: FakeImageSource(() async => null),
      projectRepository: FakeProjectRepository(
        initial: withProjects
            ? [
                sampleProject(id: 'a', name: 'gato.png', categoryId: 'c1'),
                sampleProject(
                  id: 'b',
                  name: 'casa.png',
                  updatedAt: DateTime(2024),
                ),
              ]
            : const [],
      ),
      categoryRepository: FakeCategoryRepository(
        initial: [sampleCategory(id: 'c1', name: 'Animais')],
      ),
      cameraServiceFactory: FakeCameraService.new,
      screenWakeLock: FakeScreenWakeLock(),
      themeController: theme,
    ),
  );
  await tester.pump();
  return theme;
}

Brightness _visibleBrightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

void main() {
  for (final withProjects in [false, true]) {
    final state = withProjects ? 'com listagem' : 'sem imagem';

    group('Home $state', () {
      testWidgets('não tem AppBar, título "desenha_ai" nem etiqueta no topo',
          (tester) async {
        await _pumpHome(tester, withProjects: withProjects);

        expect(find.byType(AppBar), findsNothing);
        expect(find.byType(SliverAppBar), findsNothing);
        expect(find.text('desenha_ai'), findsNothing);
        // O ícone de etiqueta que ficava no header (tooltip "Categorias").
        expect(find.byTooltip('Categorias'), findsNothing);
      });

      testWidgets('botão de sol/lua no canto superior direito, e funciona',
          (tester) async {
        await _pumpHome(tester, withProjects: withProjects);

        final button = find.byType(ThemeToggleButton);
        expect(button, findsOneWidget);
        final rect = tester.getRect(button);
        final screen = tester.getSize(find.byType(Scaffold).first);
        // Etapa 6C: 20 dp mais baixo (8 → 28) e maior (Etapa 6E: 64 dp). Nos testes a
        // SafeArea não tem recuo, então o topo é exatamente 28.
        expect(rect.top, closeTo(28, 0.5));
        expect(screen.width - rect.right, closeTo(8, 0.5));
        expect(rect.size, const Size(64, 64));

        // Fica dentro de uma SafeArea (longe de entalhes e da barra de
        // status).
        expect(
          find.ancestor(of: button, matching: find.byType(SafeArea)),
          findsWidgets,
        );

        final before = _visibleBrightness(tester);
        await tester.tap(button);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(_visibleBrightness(tester), isNot(before));
      });

      testWidgets('mostra a marca "Desenha A.I" desenhada, centralizada',
          (tester) async {
        await _pumpHome(tester, withProjects: withProjects);

        final logo = find.byType(DesenhaAiLogo);
        expect(logo, findsOneWidget);
        // Rótulo para o leitor de tela, conferido no widget `Semantics` da
        // marca. Na lista rolável, o nó semântico pode ser agrupado com os
        // vizinhos, então `bySemanticsLabel` não serve nos dois estados.
        expect(
          find.descendant(
            of: logo,
            matching: find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.label == 'Desenha A.I',
            ),
          ),
          findsOneWidget,
        );
        // Desenhada (CustomPaint), e não um texto com fonte.
        expect(
          find.descendant(
            of: logo,
            matching: find.byWidgetPredicate(
              (w) => w is CustomPaint && w.painter is DesenhaAiLogoPainter,
            ),
          ),
          findsOneWidget,
        );
        expect(find.text('Desenha A.I'), findsNothing);

        // Centralizada na horizontal.
        final screen = tester.getSize(find.byType(Scaffold).first);
        expect(tester.getCenter(logo).dx, closeTo(screen.width / 2, 2));
        // Não fica por baixo do botão de sol/lua.
        expect(
          tester
              .getRect(logo)
              .overlaps(tester.getRect(find.byType(ThemeToggleButton))),
          isFalse,
        );
      });
    });
  }

  group('sem imagem: botões lado a lado', () {
    testWidgets('"Escolher imagem" e "Categorias" na mesma linha e estilo',
        (tester) async {
      await _pumpHome(tester);

      final pick = find.byKey(HomeWelcomeView.pickButtonKey);
      final categories = find.byKey(HomeWelcomeView.categoriesButtonKey);
      expect(pick, findsOneWidget);
      expect(categories, findsOneWidget);

      final a = tester.getRect(pick);
      final b = tester.getRect(categories);
      expect(a.center.dy, closeTo(b.center.dy, 1)); // mesma linha
      expect(b.left, greaterThan(a.right)); // categoria ao lado (direita)
      expect(a.height, b.height); // mesmo molde
      expect(a.width, closeTo(b.width, 1));
      expect(
        tester.widget(pick).runtimeType,
        tester.widget(categories).runtimeType,
      );

      // Ícone de etiqueta junto ao botão de categoria.
      expect(
        find.descendant(of: categories, matching: find.byIcon(Icons.label_outline)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: categories, matching: find.text('Categorias')),
        findsOneWidget,
      );
    });

    testWidgets('o botão de categoria abre a tela de categorias',
        (tester) async {
      await _pumpHome(tester);
      await tester.tap(find.byKey(HomeWelcomeView.categoriesButtonKey));
      await settle(tester);
      expect(find.byType(CategoriesScreen), findsOneWidget);
    });

    testWidgets('cabe lado a lado num celular em pé (360 dp)',
        (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpHome(tester);

      final a = tester.getRect(find.byKey(HomeWelcomeView.pickButtonKey));
      final b = tester.getRect(find.byKey(HomeWelcomeView.categoriesButtonKey));
      expect(a.center.dy, closeTo(b.center.dy, 1));
      expect(tester.takeException(), isNull); // sem overflow
    });
  });

  group('com listagem: conteúdo abaixo da busca preservado', () {
    testWidgets('busca, faixa de categorias, cards e botões continuam',
        (tester) async {
      await _pumpHome(tester, withProjects: true);

      expect(find.byType(ProjectSearchField), findsOneWidget);
      expect(find.byType(CategoryFilterBar), findsOneWidget);
      expect(find.byType(ProjectHistoryTile), findsNWidgets(2));
      expect(find.byTooltip('Editar desenho'), findsNWidgets(2));
      expect(find.byTooltip('Excluir desenho'), findsNWidgets(2));
      expect(find.byType(CategoryBadge), findsOneWidget);
      expect(find.text('Novo desenho'), findsOneWidget);

      // A marca fica ACIMA da busca, que continua acima da lista.
      final logo = tester.getRect(find.byType(DesenhaAiLogo));
      final search = tester.getRect(find.byType(ProjectSearchField));
      expect(logo.bottom, lessThan(search.top));

      // A busca e o seletor continuam funcionando.
      await tester.enterText(
        find.descendant(
          of: find.byType(ProjectSearchField),
          matching: find.byType(TextField),
        ),
        'casa',
      );
      await tester.pump();
      expect(find.byType(ProjectHistoryTile), findsOneWidget);

      await tester.tap(find.byTooltip('Pesquisar e criar categorias'));
      await settle(tester);
      expect(find.byType(CategoryFilterScreen), findsOneWidget);
    });
  });

  group('marca e barra de status acompanham o tema', () {
    testWidgets('a marca usa as cores do tema atual', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await _pumpHome(tester);

      DesenhaAiLogoPainter painter() => tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byType(DesenhaAiLogo),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter! as DesenhaAiLogoPainter;

      expect(painter().start, AppTheme.light.colorScheme.primary);

      await tester.tap(find.byType(ThemeToggleButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(painter().start, AppTheme.dark.colorScheme.primary);
    });

    testWidgets('ícones da barra de status contrastam com o fundo',
        (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await _pumpHome(tester);

      SystemUiOverlayStyle style() => tester
          .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
          )
          .value;

      // Tema claro → ícones escuros.
      expect(style().statusBarIconBrightness, Brightness.dark);

      await tester.tap(find.byType(ThemeToggleButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      // Tema escuro → ícones claros.
      expect(style().statusBarIconBrightness, Brightness.light);
    });
  });

  group('Etapa 6C: ajustes finos', () {
    testWidgets('Etapa 6F: a marca fica 30 dp abaixo do botão de sol/lua',
        (tester) async {
      await _pumpHome(tester, withProjects: true);
      // 28 (topo do botão) + 64 (altura) + 30 = 122.
      expect(ProjectHistoryList.titleTopInset, 122);
      final toggle = tester.getRect(find.byType(ThemeToggleButton));
      final logo = tester.getRect(find.byType(DesenhaAiLogo));
      expect(logo.top - toggle.bottom, closeTo(30, 0.5));
      // Tudo abaixo da marca desceu junto: "Novo desenho" vem depois dela.
      expect(
        tester.getRect(find.text('Novo desenho')).top,
        greaterThan(logo.bottom),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('botão de sol/lua maior: área de 64 dp e ícone de 36 dp',
        (tester) async {
      await _pumpHome(tester);
      expect(tester.getSize(find.byType(ThemeToggleButton)), const Size(64, 64));
      final icon = tester.widget<IconButton>(
        find.descendant(
          of: find.byType(ThemeToggleButton),
          matching: find.byType(IconButton),
        ),
      );
      expect(icon.iconSize, 36);
      expect(tester.getSize(find.byIcon(Icons.light_mode)), const Size(36, 36));
    });

    testWidgets('a SafeArea do aparelho é respeitada (barra de status)',
        (tester) async {
      // Simula 24 dp de barra de status: o botão desce junto.
      tester.view.padding = const FakeViewPadding(top: 24);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpHome(tester);

      expect(
        tester.getRect(find.byType(ThemeToggleButton)).top,
        closeTo(24 + 28, 0.5),
      );
    });

    testWidgets(
        'tela inicial: descer/aumentar o botão NÃO mexe no layout central',
        (tester) async {
      await _pumpHome(tester);
      final screen = tester.getSize(find.byType(Scaffold).first);

      // O botão está numa camada própria (Positioned), fora do conteúdo.
      expect(
        find.descendant(
          of: find.byType(HomeWelcomeView),
          matching: find.byType(ThemeToggleButton),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.byType(ThemeToggleButton),
          matching: find.byWidgetPredicate(
            (w) => w is Positioned && w.top == 0 && w.right == 0,
          ),
        ),
        findsOneWidget,
      );

      // A tela inicial ocupa a área inteira e o bloco central continua
      // centralizado nas duas direções.
      expect(tester.getRect(find.byType(HomeWelcomeView)),
          Offset.zero & screen);
      final logo = tester.getRect(find.byType(DesenhaAiLogo));
      final buttons = tester.getRect(find.byKey(HomeWelcomeView.pickButtonKey))
          .expandToInclude(
              tester.getRect(find.byKey(HomeWelcomeView.categoriesButtonKey)));
      final block = logo.expandToInclude(buttons);
      expect(block.center.dx, closeTo(screen.width / 2, 1));
      expect(block.center.dy, closeTo(screen.height / 2, 1));

      // Os dois botões continuam lado a lado e com o mesmo tamanho.
      final a = tester.getRect(find.byKey(HomeWelcomeView.pickButtonKey));
      final b =
          tester.getRect(find.byKey(HomeWelcomeView.categoriesButtonKey));
      expect(a.center.dy, closeTo(b.center.dy, 1));
      expect(a.size, b.size);

      // E o botão de sol/lua não fica por cima de nada do bloco central.
      final toggle = tester.getRect(find.byType(ThemeToggleButton));
      expect(toggle.overlaps(block), isFalse);
    });

    testWidgets('celular em pé (360 dp): título e botão não se encostam',
        (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpHome(tester, withProjects: true);

      final logo = tester.getRect(find.byType(DesenhaAiLogo));
      final toggle = tester.getRect(find.byType(ThemeToggleButton));
      expect(logo.overlaps(toggle), isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  test('o desenho das letras é montado uma vez e tem proporção fixa', () {
    // Mesma instância de painter não repinta se as cores não mudam.
    const a = DesenhaAiLogoPainter(
      start: Colors.purple,
      end: Colors.teal,
      sketch: Colors.black,
    );
    const b = DesenhaAiLogoPainter(
      start: Colors.purple,
      end: Colors.teal,
      sketch: Colors.black,
    );
    expect(a.shouldRepaint(b), isFalse);
    expect(
      a.shouldRepaint(
        const DesenhaAiLogoPainter(
          start: Colors.orange,
          end: Colors.teal,
          sketch: Colors.black,
        ),
      ),
      isTrue,
    );
  });
}
