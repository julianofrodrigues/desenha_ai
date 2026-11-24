// Etapa 6D: editar nome e cor de uma categoria (tela "Categorias" e
// seletor da faixa), com reflexo imediato na lista e nos cards vinculados.
import 'package:desenha_ai/app.dart';
import 'package:desenha_ai/features/image_selection/presentation/widgets/home_status_views.dart';
import 'package:desenha_ai/features/projects/models/project_category.dart';
import 'package:desenha_ai/features/projects/screens/categories_screen.dart';
import 'package:desenha_ai/features/projects/screens/category_filter_screen.dart';
import 'package:desenha_ai/features/projects/widgets/category_badge.dart';
import 'package:desenha_ai/features/projects/widgets/category_form_dialog.dart';
import 'package:desenha_ai/features/projects/widgets/project_history_tile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../fakes.dart';

const _verde = 0xFF43A047;
const _cobalto = 0xFF3D5AFE; // "Azul-cobalto", uma das cores novas da 6D

final _animais = sampleCategory(id: 'c1', name: 'Animais', colorValue: _verde);
final _retratos =
    sampleCategory(id: 'c2', name: 'Retratos', colorValue: 0xFF1E88E5);

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

Finder _form() => find.byType(CategoryFormDialog);
Finder _inForm(Finder f) => find.descendant(of: _form(), matching: f);

/// Bolinha de cor de uma linha/etiqueta (pelo texto ao lado).
Color _dotColorNear(WidgetTester tester, Finder container) => tester
    .widget<CategoryColorDot>(
      find.descendant(of: container, matching: find.byType(CategoryColorDot)),
    )
    .color;

/// Badge do card de um desenho (pelo nome exibido do desenho).
Finder _badgeOf(String projectName) => find.descendant(
      of: find.widgetWithText(ProjectHistoryTile, projectName),
      matching: find.byType(CategoryBadge),
    );

void main() {
  group('tela "Categorias"', () {
    Future<FakeCategoryRepository> openScreen(WidgetTester tester) async {
      final categories = FakeCategoryRepository(initial: [_animais, _retratos]);
      await tester.pumpWidget(
        MaterialApp(
          home: CategoriesScreen(
            categoryRepository: categories,
            projectRepository: FakeProjectRepository(),
          ),
        ),
      );
      await tester.pump();
      return categories;
    }

    testWidgets('cada categoria tem o botão Editar à esquerda do Remover',
        (tester) async {
      await openScreen(tester);
      expect(find.byTooltip('Editar categoria'), findsNWidgets(2));

      final edit = tester.getCenter(find.byTooltip('Editar categoria').first);
      final remove =
          tester.getCenter(find.byTooltip('Remover categoria').first);
      expect(edit.dx, lessThan(remove.dx));
      expect(edit.dy, closeTo(remove.dy, 1));
    });

    testWidgets('o formulário abre com o nome e a cor atuais', (tester) async {
      await openScreen(tester);
      await tester.tap(find.byTooltip('Editar categoria').first); // Animais
      await settle(tester);

      expect(_inForm(find.text('Editar categoria')), findsOneWidget);
      expect(_inForm(find.text('Salvar')), findsOneWidget);
      final field = tester.widget<TextField>(_inForm(find.byType(TextField)));
      expect(field.controller!.text, 'Animais');
      final palette =
          tester.widget<CategoryColorPalette>(find.byType(CategoryColorPalette));
      expect(palette.selected, _verde);
    });

    testWidgets('salvar muda nome e cor na lista e no armazenamento',
        (tester) async {
      final categories = await openScreen(tester);
      await tester.tap(find.byTooltip('Editar categoria').first);
      await settle(tester);

      await tester.enterText(_inForm(find.byType(TextField)), 'Bichos');
      await tester.tap(find.byTooltip('Cor: Azul-cobalto'));
      await tester.pump();
      await tester.tap(_inForm(find.text('Salvar')));
      await settle(tester);

      final saved = (await categories.listAll()).firstWhere((c) => c.id == 'c1');
      expect(saved.name, 'Bichos');
      expect(saved.colorValue, _cobalto);
      expect(find.text('Categoria "Bichos" atualizada.'), findsOneWidget);
      // Na lista, o nome e a cor novos aparecem na hora.
      expect(find.text('Animais'), findsNothing);
      expect(
        _dotColorNear(tester, find.widgetWithText(ListTile, 'Bichos')),
        const Color(_cobalto),
      );
    });

    testWidgets('nome de outra categoria é recusado e o diálogo fica aberto',
        (tester) async {
      final categories = await openScreen(tester);
      await tester.tap(find.byTooltip('Editar categoria').first);
      await settle(tester);

      await tester.enterText(_inForm(find.byType(TextField)), 'retratos');
      await tester.tap(_inForm(find.text('Salvar')));
      await tester.pump();

      expect(find.text(CategoryNameError.duplicate.message), findsOneWidget);
      expect(_form(), findsOneWidget);
      expect(categories.updates, isEmpty);
    });

    testWidgets('trocar só a cor (mesmo nome) é permitido', (tester) async {
      final categories = await openScreen(tester);
      await tester.tap(find.byTooltip('Editar categoria').first);
      await settle(tester);

      await tester.tap(find.byTooltip('Cor: Grafite'));
      await tester.pump();
      await tester.tap(_inForm(find.text('Salvar')));
      await settle(tester);

      expect(categories.updates.single.name, 'Animais');
      expect(categories.updates.single.colorValue, 0xFF37474F);
    });

    testWidgets('cancelar ou salvar sem mudar nada não grava', (tester) async {
      final categories = await openScreen(tester);

      await tester.tap(find.byTooltip('Editar categoria').first);
      await settle(tester);
      await tester.tap(find.byTooltip('Cor: Vinho'));
      await tester.tap(_inForm(find.text('Cancelar')));
      await settle(tester);

      await tester.tap(find.byTooltip('Editar categoria').first);
      await settle(tester);
      await tester.tap(_inForm(find.text('Salvar')));
      await settle(tester);

      expect(categories.updates, isEmpty);
      expect(
        _dotColorNear(tester, find.widgetWithText(ListTile, 'Animais')),
        const Color(_verde),
      );
    });
  });

  group('paleta de 30 cores no formulário', () {
    testWidgets('criar e editar mostram as 30 cores', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CategoriesScreen(
            categoryRepository: FakeCategoryRepository(initial: [_animais]),
            projectRepository: FakeProjectRepository(),
          ),
        ),
      );
      await tester.pump();

      // Criar.
      await tester.tap(find.text('Nova categoria'));
      await settle(tester);
      for (final c in categoryPalette) {
        expect(find.byTooltip('Cor: ${c.name}'), findsOneWidget,
            reason: c.name);
      }
      await tester.tap(_inForm(find.text('Cancelar')));
      await settle(tester);

      // Editar.
      await tester.tap(find.byTooltip('Editar categoria'));
      await settle(tester);
      expect(
        find.descendant(
          of: find.byType(CategoryColorPalette),
          matching: find.byType(CategoryColorDot),
        ),
        findsNWidgets(30),
      );
      expect(tester.takeException(), isNull); // sem overflow
    });

    testWidgets('a grade é compacta: não estica o diálogo no tablet',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: CategoriesScreen(
            categoryRepository: FakeCategoryRepository(),
            projectRepository: FakeProjectRepository(),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Nova categoria'));
      await settle(tester);

      final grid = tester.getSize(find.byType(CategoryColorPalette));
      // 6 colunas de 40 dp + 5 espaços de 6 dp.
      expect(grid.width, 6 * 40 + 5 * 6);
      // A caixa VISÍVEL do diálogo é o `Material` dentro dele (o widget
      // `AlertDialog` em si ocupa a tela toda, por causa do recuo e do
      // alinhamento).
      final box = tester.getSize(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(box.width, lessThan(600));
    });

    testWidgets('celular (360 dp): 5 colunas e tudo cabe', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: CategoriesScreen(
            categoryRepository: FakeCategoryRepository(),
            projectRepository: FakeProjectRepository(),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Nova categoria'));
      await settle(tester);

      expect(tester.getSize(find.byType(CategoryColorPalette)).width,
          5 * 40 + 4 * 6);
      expect(tester.takeException(), isNull);
    });
  });

  group('reflexo nos cards vinculados', () {
    testWidgets('editar pelo seletor da faixa atualiza as badges dos cards',
        (tester) async {
      final projects = FakeProjectRepository(initial: [
        sampleProject(id: 'a', name: 'gato.png', categoryId: 'c1'),
        sampleProject(
          id: 'b',
          name: 'rosto.png',
          categoryId: 'c2',
          updatedAt: DateTime(2024),
        ),
      ]);
      final categories = FakeCategoryRepository(initial: [_animais, _retratos]);
      await _pumpApp(tester, projects: projects, categories: categories);
      expect(
        find.descendant(of: _badgeOf('gato.png'), matching: find.text('Animais')),
        findsOneWidget,
      );

      // Marca "Animais" no filtro e edita a categoria pelo seletor.
      await tester.tap(find.byTooltip('Pesquisar e criar categorias'));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(CategoryFilterScreen),
          matching: find.text('Animais'),
        ),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Editar categoria').first);
      await settle(tester);
      await tester.enterText(_inForm(find.byType(TextField)), 'Bichos');
      await tester.tap(find.byTooltip('Cor: Azul-cobalto'));
      await tester.tap(_inForm(find.text('Salvar')));
      await settle(tester);

      // No seletor: nome novo e a marcação continua (o id não mudou).
      final row = find.widgetWithText(ListTile, 'Bichos');
      expect(row, findsOneWidget);
      expect(
        tester
            .widget<Checkbox>(
              find.descendant(of: row, matching: find.byType(Checkbox)),
            )
            .value,
        isTrue,
      );

      await tester.tap(find.byKey(CategoryFilterScreen.applyButtonKey));
      await settle(tester);

      // Na Home: o card mostra o nome e a cor novos, sem mexer no desenho.
      expect(
        find.descendant(of: _badgeOf('gato.png'), matching: find.text('Bichos')),
        findsOneWidget,
      );
      expect(_dotColorNear(tester, _badgeOf('gato.png')), const Color(_cobalto));
      expect(projects['a']!.categoryId, 'c1');
      expect(projects.edits, isEmpty); // nenhum projeto foi regravado
      // O filtro continua ativo, agora com a etiqueta renomeada.
      expect(find.widgetWithText(InputChip, 'Bichos'), findsOneWidget);
      // O outro desenho não foi afetado.
      expect(find.text('rosto.png'), findsNothing); // fora do filtro
    });

    testWidgets('editar pela tela "Categorias" atualiza os cards ao voltar',
        (tester) async {
      final categories = FakeCategoryRepository(initial: [_animais]);
      final projects = FakeProjectRepository();
      await _pumpApp(tester, projects: projects, categories: categories);

      // Sem desenhos: a tela "Categorias" abre pelo botão da tela inicial.
      await tester.tap(find.byKey(HomeWelcomeView.categoriesButtonKey));
      await settle(tester);
      await tester.tap(find.byTooltip('Editar categoria'));
      await settle(tester);
      await tester.tap(find.byTooltip('Cor: Lavanda'));
      await tester.tap(_inForm(find.text('Salvar')));
      await settle(tester);

      expect(
        (await categories.listAll()).single.colorValue,
        0xFF9575CD,
      );
    });
  });
}
