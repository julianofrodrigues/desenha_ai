// Fase 5 (Etapa 5A): telas de categorias, escolha de categoria no Editar e
// badge (cor + nome) no card. Tudo com os repositórios FALSOS de fakes.dart.
import 'package:desenha_ai/app.dart';
import 'package:desenha_ai/features/projects/models/project_category.dart';
import 'package:desenha_ai/features/projects/screens/categories_screen.dart';
import 'package:desenha_ai/features/projects/widgets/category_badge.dart';
import 'package:desenha_ai/features/projects/widgets/category_form_dialog.dart';
import 'package:desenha_ai/features/projects/widgets/edit_project_dialog.dart';
import 'package:desenha_ai/features/projects/widgets/project_history_tile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../fakes.dart';

Future<void> _pumpApp(
  WidgetTester tester, {
  required FakeProjectRepository projects,
  required FakeCategoryRepository categories,
}) async {
  await tester.pumpWidget(
    DesenhaAiApp(
      imageSource: FakeImageSource(() async => null),
      projectRepository: projects,
      categoryRepository: categories,
      cameraServiceFactory: FakeCameraService.new,
      screenWakeLock: FakeScreenWakeLock(),
      themeController: fakeThemeController(),
    ),
  );
  await tester.pump();
}

Finder _inDialog<T>(Finder finder) =>
    find.descendant(of: find.byType(T), matching: finder);

/// A badge de um card específico (pelo nome exibido do projeto).
Finder _badgeOf(String projectName) => find.descendant(
      of: find.widgetWithText(ProjectHistoryTile, projectName),
      matching: find.byType(CategoryBadge),
    );

void main() {
  final animais = sampleCategory(id: 'c1', name: 'Animais', colorValue: 0xFF43A047);
  final retratos =
      sampleCategory(id: 'c2', name: 'Retratos', colorValue: 0xFF1E88E5);

  group('badge no card', () {
    testWidgets('mostra a cor e o nome da categoria', (tester) async {
      await _pumpApp(
        tester,
        projects: FakeProjectRepository(
          initial: [sampleProject(name: 'gato.png', categoryId: 'c1')],
        ),
        categories: FakeCategoryRepository(initial: [animais]),
      );

      expect(_badgeOf('gato.png'), findsOneWidget);
      expect(
        find.descendant(of: _badgeOf('gato.png'), matching: find.text('Animais')),
        findsOneWidget,
      );
      // A bolinha usa exatamente a cor da categoria.
      final dot = tester.widget<CategoryColorDot>(
        find.descendant(
          of: _badgeOf('gato.png'),
          matching: find.byType(CategoryColorDot),
        ),
      );
      expect(dot.color, const Color(0xFF43A047));
      // Rótulo único para o leitor de tela. Conferimos no widget `Semantics`
      // da badge: o `ListTile` junta a semântica dos filhos num nó só (o que
      // é o certo para o leitor de tela), então `bySemanticsLabel` não acha
      // o rótulo isolado.
      expect(
        find.descendant(
          of: _badgeOf('gato.png'),
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == 'Categoria: Animais',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('sem categoria, ou categoria apagada, não mostra badge',
        (tester) async {
      await _pumpApp(
        tester,
        projects: FakeProjectRepository(initial: [
          sampleProject(id: 'a', name: 'sem.png'),
          sampleProject(id: 'b', name: 'orfao.png', categoryId: 'apagada'),
        ]),
        categories: FakeCategoryRepository(initial: [animais]),
      );

      expect(find.byType(CategoryBadge), findsNothing);
      // Os cards continuam lá, normais.
      expect(find.text('sem.png'), findsOneWidget);
      expect(find.text('orfao.png'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('categoria no Editar', () {
    testWidgets('escolher uma categoria salva e mostra a badge na hora',
        (tester) async {
      final projects = FakeProjectRepository(
        initial: [sampleProject(name: 'gato.png')],
      );
      await _pumpApp(
        tester,
        projects: projects,
        categories: FakeCategoryRepository(initial: [animais, retratos]),
      );
      expect(find.byType(CategoryBadge), findsNothing);

      await tester.tap(find.byTooltip('Editar desenho'));
      await settle(tester);
      // Começa em "Sem categoria".
      final semCategoria = tester.widget<ChoiceChip>(
        _inDialog<EditProjectDialog>(
          find.widgetWithText(ChoiceChip, 'Sem categoria'),
        ),
      );
      expect(semCategoria.selected, isTrue);

      await tester.tap(_inDialog<EditProjectDialog>(find.text('Retratos')));
      await tester.pump();
      await tester.tap(find.text('Salvar'));
      await settle(tester);

      expect(projects['p1']!.categoryId, 'c2');
      expect(projects['p1']!.customName, isNull); // nome não mudou
      expect(find.text('Categoria atualizada.'), findsOneWidget);
      expect(
        find.descendant(of: _badgeOf('gato.png'), matching: find.text('Retratos')),
        findsOneWidget,
      );
    });

    testWidgets('nome e categoria são salvos juntos', (tester) async {
      final projects = FakeProjectRepository(
        initial: [sampleProject(name: 'gato.png')],
      );
      await _pumpApp(
        tester,
        projects: projects,
        categories: FakeCategoryRepository(initial: [animais]),
      );

      await tester.tap(find.byTooltip('Editar desenho'));
      await settle(tester);
      await tester.enterText(
        _inDialog<EditProjectDialog>(find.byType(TextField)),
        'Gato laranja',
      );
      await tester.tap(_inDialog<EditProjectDialog>(find.text('Animais')));
      await tester.pump();
      await tester.tap(find.text('Salvar'));
      await settle(tester);

      expect(projects.edits.single, (customName: 'Gato laranja', categoryId: 'c1'));
      expect(find.text('Desenho atualizado.'), findsOneWidget);
      expect(
        find.descendant(
          of: _badgeOf('Gato laranja'),
          matching: find.text('Animais'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('"Sem categoria" remove o vínculo', (tester) async {
      final projects = FakeProjectRepository(
        initial: [sampleProject(name: 'gato.png', categoryId: 'c1')],
      );
      await _pumpApp(
        tester,
        projects: projects,
        categories: FakeCategoryRepository(initial: [animais]),
      );
      expect(find.byType(CategoryBadge), findsOneWidget);

      await tester.tap(find.byTooltip('Editar desenho'));
      await settle(tester);
      await tester.tap(_inDialog<EditProjectDialog>(find.text('Sem categoria')));
      await tester.pump();
      await tester.tap(find.text('Salvar'));
      await settle(tester);

      expect(projects['p1']!.categoryId, isNull);
      expect(find.byType(CategoryBadge), findsNothing);
    });

    testWidgets('cancelar não muda a categoria', (tester) async {
      final projects = FakeProjectRepository(
        initial: [sampleProject(name: 'gato.png', categoryId: 'c1')],
      );
      await _pumpApp(
        tester,
        projects: projects,
        categories: FakeCategoryRepository(initial: [animais, retratos]),
      );

      await tester.tap(find.byTooltip('Editar desenho'));
      await settle(tester);
      await tester.tap(_inDialog<EditProjectDialog>(find.text('Retratos')));
      await tester.pump();
      await tester.tap(find.text('Cancelar'));
      await settle(tester);

      expect(projects.edits, isEmpty);
      expect(
        find.descendant(of: _badgeOf('gato.png'), matching: find.text('Animais')),
        findsOneWidget,
      );
    });

    testWidgets('sem categorias criadas, o diálogo explica como criar',
        (tester) async {
      await _pumpApp(
        tester,
        projects: FakeProjectRepository(initial: [sampleProject()]),
        categories: FakeCategoryRepository(),
      );
      await tester.tap(find.byTooltip('Editar desenho'));
      await settle(tester);

      expect(
        find.textContaining('Você ainda não criou categorias'),
        findsOneWidget,
      );
    });
  });

  group('tela de categorias', () {
    Future<void> openCategories(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Categorias'));
      await settle(tester);
      expect(find.byType(CategoriesScreen), findsOneWidget);
    }

    testWidgets('criar categoria com nome e cor escolhida', (tester) async {
      final categories = FakeCategoryRepository();
      await _pumpApp(
        tester,
        projects: FakeProjectRepository(),
        categories: categories,
      );
      await openCategories(tester);
      expect(find.text('Nenhuma categoria ainda'), findsOneWidget);

      await tester.tap(find.text('Nova categoria'));
      await settle(tester);
      await tester.enterText(
        _inDialog<CategoryFormDialog>(find.byType(TextField)),
        '  Paisagens ',
      );
      await tester.tap(find.byTooltip('Cor: Azul'));
      await tester.pump();
      await tester.tap(find.text('Criar'));
      await settle(tester);

      final saved = (await categories.listAll()).single;
      expect(saved.name, 'Paisagens');
      expect(saved.colorValue, 0xFF1E88E5);
      expect(find.text('Paisagens'), findsOneWidget);
      expect(find.text('Categoria "Paisagens" criada.'), findsOneWidget);
    });

    testWidgets('nome vazio ou duplicado mostra erro e não fecha o diálogo',
        (tester) async {
      final categories = FakeCategoryRepository(initial: [animais]);
      await _pumpApp(
        tester,
        projects: FakeProjectRepository(),
        categories: categories,
      );
      await openCategories(tester);

      await tester.tap(find.text('Nova categoria'));
      await settle(tester);
      final field = _inDialog<CategoryFormDialog>(find.byType(TextField));

      await tester.enterText(field, '   ');
      await tester.tap(find.text('Criar'));
      await tester.pump();
      expect(find.text(CategoryNameError.empty.message), findsOneWidget);

      await tester.enterText(field, 'animais');
      await tester.tap(find.text('Criar'));
      await tester.pump();
      expect(find.text(CategoryNameError.duplicate.message), findsOneWidget);

      // O diálogo continua aberto e nada foi criado.
      expect(find.byType(CategoryFormDialog), findsOneWidget);
      expect(await categories.listAll(), hasLength(1));
    });

    testWidgets(
        'remover pede confirmação e deixa os desenhos sem categoria',
        (tester) async {
      final projects = FakeProjectRepository(initial: [
        sampleProject(id: 'a', name: 'gato.png', categoryId: 'c1'),
        sampleProject(id: 'b', name: 'cao.png', categoryId: 'c1'),
        sampleProject(id: 'c', name: 'rosto.png', categoryId: 'c2'),
      ]);
      final categories = FakeCategoryRepository(initial: [animais, retratos]);
      await _pumpApp(tester, projects: projects, categories: categories);
      expect(find.byType(CategoryBadge), findsNWidgets(3));

      await openCategories(tester);
      // "Animais" é a primeira (ordem alfabética).
      await tester.tap(find.byTooltip('Remover categoria').first);
      await settle(tester);
      expect(find.text('Remover categoria?'), findsOneWidget);

      await tester.tap(find.text('Remover'));
      await settle(tester);

      expect(categories.deleted, ['c1']);
      expect(projects['a']!.categoryId, isNull);
      expect(projects['b']!.categoryId, isNull);
      expect(projects['c']!.categoryId, 'c2');
      expect(
        find.text('Categoria removida. 2 desenhos ficaram sem categoria.'),
        findsOneWidget,
      );

      // De volta à Home: só sobrou a badge de "Retratos".
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(find.byType(CategoryBadge), findsOneWidget);
      expect(
        find.descendant(of: _badgeOf('rosto.png'), matching: find.text('Retratos')),
        findsOneWidget,
      );
    });

    testWidgets('cancelar a remoção mantém a categoria', (tester) async {
      final categories = FakeCategoryRepository(initial: [animais]);
      await _pumpApp(
        tester,
        projects: FakeProjectRepository(),
        categories: categories,
      );
      await openCategories(tester);

      await tester.tap(find.byTooltip('Remover categoria'));
      await settle(tester);
      await tester.tap(find.text('Cancelar'));
      await settle(tester);

      expect(categories.deleted, isEmpty);
      expect(find.text('Animais'), findsOneWidget);
    });
  });

  test('a paleta tem cores diferentes e nomes únicos', () {
    expect(categoryPalette.map((c) => c.value).toSet(), hasLength(12));
    expect(categoryPalette.map((c) => c.name).toSet(), hasLength(12));
  });
}
