// Seleção múltipla na Home: escolher uma ou várias imagens cria os projetos
// e mostra a LISTAGEM, sem abrir a tela de desenho. Vale para a tela inicial
// ("Escolher imagem") e para a listagem ("Novo desenho").
import 'dart:async';
import 'dart:typed_data';

import 'package:desenha_ai/app.dart';
import 'package:desenha_ai/features/drawing/screens/drawing_screen.dart';
import 'package:desenha_ai/features/image_selection/data/local_image_source.dart';
import 'package:desenha_ai/features/image_selection/presentation/widgets/home_status_views.dart';
import 'package:desenha_ai/features/projects/screens/category_filter_screen.dart';
import 'package:desenha_ai/features/projects/widgets/project_history_tile.dart';
import 'package:desenha_ai/features/projects/widgets/project_search_field.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../fakes.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeImageSource source, {
  FakeProjectRepository? repository,
  FakeCategoryRepository? categories,
}) async {
  // Tela alta: a lista é preguiçosa e só constrói os cards visíveis.
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final theme = fakeThemeController();
  addTearDown(theme.dispose);
  await tester.pumpWidget(
    DesenhaAiApp(
      imageSource: source,
      projectRepository: repository ?? FakeProjectRepository(),
      categoryRepository: categories ?? FakeCategoryRepository(),
      cameraServiceFactory: FakeCameraService.new,
      screenWakeLock: FakeScreenWakeLock(),
      themeController: theme,
    ),
  );
  await tester.pump();
}

FakeImageSource _picksMany(List<String> names) => FakeImageSource.many(
      () async => [for (final n in names) PickedImage(name: n, bytes: pngBytes)],
    );

List<String> _visibleNames(WidgetTester tester) => tester
    .widgetList<ProjectHistoryTile>(find.byType(ProjectHistoryTile))
    .map((t) => t.project.originalName)
    .toList();

void main() {
  group('a partir da tela inicial ("Escolher imagem")', () {
    testWidgets('várias imagens: cria todas e mostra a listagem',
        (tester) async {
      final repo = FakeProjectRepository();
      await _pump(tester, _picksMany(['a.png', 'b.png', 'c.png']),
          repository: repo);

      await tester.tap(find.byKey(HomeWelcomeView.pickButtonKey));
      await settle(tester);

      expect(find.byType(DrawingScreen), findsNothing);
      expect(find.byType(HomeWelcomeView), findsNothing);
      expect(find.text('Continuar desenhando'), findsOneWidget);
      // As três no histórico (a mais recente primeiro).
      expect(_visibleNames(tester), ['c.png', 'b.png', 'a.png']);
      expect(repo.createCalls, ['a.png', 'b.png', 'c.png']);
      expect(find.text('3 imagens adicionadas ao histórico.'), findsOneWidget);
    });

    testWidgets('uma imagem também vai para a listagem', (tester) async {
      await _pump(tester, _picksMany(['gato.png']));
      await tester.tap(find.byKey(HomeWelcomeView.pickButtonKey));
      await settle(tester);

      expect(find.byType(DrawingScreen), findsNothing);
      expect(_visibleNames(tester), ['gato.png']);
    });

    testWidgets('mostra "Salvando imagem N de T…" enquanto copia',
        (tester) async {
      final second = Completer<Uint8List>();
      final source = FakeImageSource.many(() async => [
            PickedImage(name: 'a.png', bytes: pngBytes),
            PickedImage.lazy(name: 'b.png', read: () => second.future),
            PickedImage(name: 'c.png', bytes: pngBytes),
          ]);
      await _pump(tester, source);

      await tester.tap(find.byKey(HomeWelcomeView.pickButtonKey));
      await tester.pump();
      await tester.pump();
      expect(find.text('Salvando imagem 2 de 3…'), findsOneWidget);

      second.complete(pngBytes);
      await settle(tester);
      expect(_visibleNames(tester), hasLength(3));
    });

    testWidgets('cancelar a galeria não cria nada nem mostra erro',
        (tester) async {
      final repo = FakeProjectRepository();
      await _pump(tester, _picksMany(const []), repository: repo);
      await tester.tap(find.byKey(HomeWelcomeView.pickButtonKey));
      await settle(tester);

      expect(find.byType(HomeWelcomeView), findsOneWidget);
      expect(find.text('Tentar novamente'), findsNothing);
      expect(repo.createCalls, isEmpty);
    });

    testWidgets('se TODAS falharem, mostra o erro e permite tentar de novo',
        (tester) async {
      final source = FakeImageSource.many(() async => [
            PickedImage(name: 'vazia.png', bytes: Uint8List(0)),
            PickedImage(name: 'vazia2.png', bytes: Uint8List(0)),
          ]);
      await _pump(tester, source);
      await tester.tap(find.byKey(HomeWelcomeView.pickButtonKey));
      await settle(tester);

      expect(
        find.textContaining('nenhuma das 2 imagens'),
        findsOneWidget,
      );
      expect(find.text('Tentar novamente'), findsOneWidget);

      source.onPickMany =
          () async => [PickedImage(name: 'boa.png', bytes: pngBytes)];
      await tester.tap(find.text('Tentar novamente'));
      await settle(tester);
      expect(_visibleNames(tester), ['boa.png']);
      expect(find.byType(DrawingScreen), findsNothing);
    });
  });

  group('a partir da listagem ("Novo desenho")', () {
    testWidgets('adiciona as novas à listagem e NÃO abre o desenho',
        (tester) async {
      final repo = FakeProjectRepository(initial: [
        sampleProject(id: 'velho', name: 'velho.png', updatedAt: DateTime(2024)),
      ]);
      final source = _picksMany(['x.png', 'y.png']);
      await _pump(tester, source, repository: repo);
      expect(_visibleNames(tester), ['velho.png']);

      await tester.tap(find.text('Novo desenho'));
      await settle(tester);

      expect(source.calls, 1);
      expect(find.byType(DrawingScreen), findsNothing);
      expect(find.text('Continuar desenhando'), findsOneWidget);
      expect(_visibleNames(tester), ['y.png', 'x.png', 'velho.png']);
      expect(find.text('2 imagens adicionadas ao histórico.'), findsOneWidget);
    });

    testWidgets('limpa a busca para as imagens novas aparecerem',
        (tester) async {
      final repo = FakeProjectRepository(initial: [
        sampleProject(id: 'velho', name: 'velho.png', updatedAt: DateTime(2024)),
      ]);
      await _pump(tester, _picksMany(['novo.png']), repository: repo);

      final search = find.descendant(
        of: find.byType(ProjectSearchField),
        matching: find.byType(TextField),
      );
      await tester.enterText(search, 'velho');
      await tester.pump();

      await tester.tap(find.text('Novo desenho'));
      await settle(tester);

      expect(tester.widget<TextField>(search).controller!.text, isEmpty);
      expect(_visibleNames(tester), ['novo.png', 'velho.png']);
    });

    testWidgets('limpa o filtro de categoria para as novas aparecerem',
        (tester) async {
      final repo = FakeProjectRepository(initial: [
        sampleProject(
          id: 'velho',
          name: 'velho.png',
          categoryId: 'c1',
          updatedAt: DateTime(2024),
        ),
      ]);
      await _pump(
        tester,
        _picksMany(['novo.png']),
        repository: repo,
        categories: FakeCategoryRepository(
          initial: [sampleCategory(id: 'c1', name: 'Animais')],
        ),
      );
      // Filtra por "Animais" pelo seletor de categorias.
      await tester.tap(find.byTooltip('Pesquisar e criar categorias'));
      await settle(tester);
      await tester.tap(find.descendant(
        of: find.byType(CategoryFilterScreen),
        matching: find.text('Animais'),
      ));
      await tester.pump();
      await tester.tap(find.byKey(CategoryFilterScreen.applyButtonKey));
      await settle(tester);
      expect(find.text('Categorias (1)'), findsOneWidget);

      await tester.tap(find.text('Novo desenho'));
      await settle(tester);

      // A nova (sem categoria) aparece, porque o filtro foi limpo.
      expect(_visibleNames(tester), ['novo.png', 'velho.png']);
      expect(find.text('Categorias (1)'), findsNothing);
    });

    testWidgets('com falha parcial, adiciona as boas e avisa',
        (tester) async {
      final repo = FakeProjectRepository(initial: [
        sampleProject(id: 'velho', name: 'velho.png', updatedAt: DateTime(2024)),
      ]);
      final source = FakeImageSource.many(() async => [
            PickedImage(name: 'boa.png', bytes: pngBytes),
            PickedImage(name: 'vazia.png', bytes: Uint8List(0)),
          ]);
      await _pump(tester, source, repository: repo);

      await tester.tap(find.text('Novo desenho'));
      await settle(tester);

      expect(_visibleNames(tester), ['boa.png', 'velho.png']);
      expect(
        find.text('"boa.png" foi adicionada ao histórico. 1 não pôde ser '
            'adicionada.'),
        findsOneWidget,
      );
    });

    testWidgets('cancelar mantém a listagem como estava', (tester) async {
      final repo = FakeProjectRepository(initial: [
        sampleProject(id: 'velho', name: 'velho.png'),
      ]);
      await _pump(tester, _picksMany(const []), repository: repo);

      await tester.tap(find.text('Novo desenho'));
      await settle(tester);

      expect(_visibleNames(tester), ['velho.png']);
      expect(find.text('Tentar novamente'), findsNothing);
    });

    testWidgets('depois de adicionar, tocar numa imagem abre o desenho dela',
        (tester) async {
      await _pump(tester, _picksMany(['a.png', 'b.png']));
      await tester.tap(find.byKey(HomeWelcomeView.pickButtonKey));
      await settle(tester);

      await tester.tap(find.text('a.png'));
      await settle(tester);
      final screen = tester.widget<DrawingScreen>(find.byType(DrawingScreen));
      expect(screen.project.originalName, 'a.png');
    });
  });
}
