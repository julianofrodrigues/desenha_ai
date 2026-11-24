// Fase 6 (Etapa 6F): nenhuma tela com header; seta de voltar acima de um
// título centralizado; sol/lua no canto superior direito de TODAS as telas;
// "Limpar" e "Adicionar categoria" abaixo da pesquisa do seletor.
import 'package:desenha_ai/app.dart';
import 'package:desenha_ai/core/widgets/page_header.dart';
import 'package:desenha_ai/features/drawing/screens/drawing_screen.dart';
import 'package:desenha_ai/features/drawing/widgets/lock_button.dart';
import 'package:desenha_ai/features/projects/screens/categories_screen.dart';
import 'package:desenha_ai/features/projects/screens/category_filter_screen.dart';
import 'package:desenha_ai/features/projects/widgets/category_form_dialog.dart';
import 'package:desenha_ai/features/theme/widgets/theme_toggle_button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../fakes.dart';

Future<void> _pumpCategories(WidgetTester tester, {Size? size}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  final theme = fakeThemeController();
  addTearDown(theme.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: CategoriesScreen(
        categoryRepository: FakeCategoryRepository(
          initial: [sampleCategory(id: 'c1', name: 'Animais')],
        ),
        projectRepository: FakeProjectRepository(),
        themeController: theme,
      ),
    ),
  );
  await tester.pump();
}

/// Home com histórico (tela alta) e o seletor de categorias já aberto.
Future<void> _openPicker(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final theme = fakeThemeController();
  addTearDown(theme.dispose);
  await tester.pumpWidget(
    DesenhaAiApp(
      imageSource: FakeImageSource(() async => null),
      projectRepository: FakeProjectRepository(
        initial: [sampleProject(id: 'a', name: 'gato.png')],
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
  await tester.tap(find.byTooltip('Pesquisar e criar categorias'));
  await settle(tester);
  expect(find.byType(CategoryFilterScreen), findsOneWidget);
}

Finder _inPicker(Finder f) =>
    find.descendant(of: find.byType(CategoryFilterScreen), matching: f);

void main() {
  group('cabeçalho sem header (PageHeader)', () {
    testWidgets('Categorias: sem AppBar, seta acima do título centralizado',
        (tester) async {
      await _pumpCategories(tester);
      final screen = tester.getSize(find.byType(Scaffold));

      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(SliverAppBar), findsNothing);
      expect(find.byType(CloseButton), findsNothing);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      final back = tester.getRect(find.byKey(PageHeader.backButtonKey));
      final title = tester.getRect(find.byKey(PageHeader.titleKey));
      final toggle = tester.getRect(find.byType(ThemeToggleButton));

      // Título centralizado e BEM abaixo do topo (fora da faixa de 56 dp de
      // uma AppBar), com a seta um pouco acima dele.
      expect(title.center.dx, closeTo(screen.width / 2, 1));
      expect(title.top, greaterThan(100));
      expect(back.bottom, lessThan(title.top));
      expect(back.left, lessThan(screen.width / 4));

      // Sol/lua no canto superior direito, na mesma altura da Home.
      expect(toggle.top, closeTo(PageHeader.topInset, 0.5));
      expect(toggle.right, closeTo(screen.width - 8, 0.5));
      expect(toggle.size, const Size(64, 64));
      // Nada se encosta.
      expect(toggle.overlaps(title), isFalse);
      expect(toggle.overlaps(back), isFalse);
    });

    testWidgets('Categorias: a seta volta para a tela anterior',
        (tester) async {
      final theme = fakeThemeController();
      addTearDown(theme.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CategoriesScreen(
                    categoryRepository: FakeCategoryRepository(),
                    projectRepository: FakeProjectRepository(),
                    themeController: theme,
                  ),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await settle(tester);
      expect(find.byType(CategoriesScreen), findsOneWidget);

      await tester.tap(find.byKey(PageHeader.backButtonKey));
      await settle(tester);
      expect(find.byType(CategoriesScreen), findsNothing);
    });

    testWidgets('Categorias: o sol/lua funciona nesta tela', (tester) async {
      final theme = fakeThemeController();
      addTearDown(theme.dispose);
      await tester.pumpWidget(
        ListenableBuilder(
          listenable: theme.mode,
          builder: (context, _) => MaterialApp(
            themeMode: theme.mode.value,
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            home: CategoriesScreen(
              categoryRepository: FakeCategoryRepository(),
              projectRepository: FakeProjectRepository(),
              themeController: theme,
            ),
          ),
        ),
      );
      await tester.pump();
      final before = theme.mode.value;
      await tester.tap(find.byType(ThemeToggleButton));
      await tester.pump(const Duration(milliseconds: 500));
      expect(theme.mode.value, isNot(before));
    });

    testWidgets('celular deitado: sem overflow no cabeçalho', (tester) async {
      await _pumpCategories(tester, size: const Size(740, 360));
      expect(tester.takeException(), isNull);
    });
  });

  group('seletor de categorias', () {
    testWidgets('seta no lugar do "X", título centralizado e sol/lua',
        (tester) async {
      await _openPicker(tester);
      expect(find.byType(AppBar), findsNothing);
      expect(_inPicker(find.byType(CloseButton)), findsNothing);
      expect(_inPicker(find.byIcon(Icons.close)), findsNothing);
      expect(_inPicker(find.byKey(PageHeader.backButtonKey)), findsOneWidget);
      expect(_inPicker(find.byType(ThemeToggleButton)), findsOneWidget);

      final screen = tester.getSize(find.byType(CategoryFilterScreen));
      final title = tester.getRect(_inPicker(find.byKey(PageHeader.titleKey)));
      expect(title.center.dx, closeTo(screen.width / 2, 1));
      expect(tester.widget<Text>(_inPicker(find.byKey(PageHeader.titleKey))).data,
          'Filtrar por categoria');
    });

    testWidgets('"Limpar" e "Adicionar categoria" abaixo da pesquisa, à '
        'direita', (tester) async {
      await _openPicker(tester);
      final screen = tester.getSize(find.byType(CategoryFilterScreen));
      final search = tester.getRect(_inPicker(find.byType(TextField)));
      final clear = tester.getRect(find.byKey(CategoryFilterScreen.clearButtonKey));
      final add = tester.getRect(find.byKey(CategoryFilterScreen.addButtonKey));

      expect(clear.top, greaterThan(search.bottom));
      expect(add.top, greaterThan(search.bottom));
      // Alinhados à DIREITA: "Adicionar" encostado na margem direita e
      // "Limpar" logo à esquerda dele, na mesma linha. (Não medimos "metade
      // da tela": a fonte dos testes é mais larga que a do aparelho.)
      expect(add.right, closeTo(screen.width - 16, 1));
      expect(add.left - clear.right, closeTo(8, 0.5));
      expect(clear.center.dy, closeTo(add.center.dy, 1));
      expect(clear.left, greaterThan(16));

      // Mesmo molde dos botões da tela sem imagem: 56 dp de altura.
      expect(add.height, 56);
      expect(_inPicker(find.text('Adicionar categoria')), findsOneWidget);
    });

    testWidgets('"Adicionar categoria" abre o formulário', (tester) async {
      await _openPicker(tester);
      await tester.tap(find.byKey(CategoryFilterScreen.addButtonKey));
      await settle(tester);
      expect(find.byType(CategoryFormDialog), findsOneWidget);
    });

    testWidgets('celular deitado com pouca altura: rola, sem overflow',
        (tester) async {
      // Abre numa tela alta (o botão da faixa fica visível) e depois gira o
      // "aparelho" para um celular deitado.
      await _openPicker(tester);
      tester.view.physicalSize = const Size(740, 360);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('tela de desenho', () {
    testWidgets('sol/lua à esquerda do cadeado; some ao travar',
        (tester) async {
      final theme = fakeThemeController();
      addTearDown(theme.dispose);
      final project = sampleProject();
      await tester.pumpWidget(
        MaterialApp(
          home: DrawingScreen(
            project: project,
            imageBytes: pngBytes,
            projectRepository: FakeProjectRepository(initial: [project]),
            cameraServiceFactory: FakeCameraService.new,
            screenWakeLock: FakeScreenWakeLock(),
            themeController: theme,
          ),
        ),
      );
      await tester.pump();

      final toggle = tester.getRect(find.byType(ThemeToggleButton));
      final lock = tester.getRect(find.byType(LockButton));
      expect(toggle.right, lessThanOrEqualTo(lock.left));
      expect(toggle.top, closeTo(lock.top, 1));
      expect(toggle.overlaps(lock), isFalse);

      await tester.tap(find.byType(LockButton));
      await tester.pump();
      expect(find.byType(ThemeToggleButton), findsNothing);
    });
  });
}
