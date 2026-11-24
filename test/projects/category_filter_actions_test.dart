// Seletor de categorias: "Limpar" à esquerda (mesmo molde do "Adicionar
// categoria") e "Selecionar todas" logo abaixo de "Sem categoria".
import 'package:desenha_ai/app.dart';
import 'package:desenha_ai/features/projects/screens/category_filter_screen.dart';
import 'package:desenha_ai/features/projects/widgets/project_history_tile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../fakes.dart';

final _animais = sampleCategory(id: 'c1', name: 'Animais');
final _retratos =
    sampleCategory(id: 'c2', name: 'Retratos', colorValue: 0xFF1E88E5);
final _paisagens =
    sampleCategory(id: 'c3', name: 'Paisagens', colorValue: 0xFFFFB300);

/// Home com histórico (tela alta, como um tablet em pé) e o seletor aberto.
Future<void> _openPicker(
  WidgetTester tester, {
  bool withCategories = true,
}) async {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final theme = fakeThemeController();
  addTearDown(theme.dispose);
  await tester.pumpWidget(
    DesenhaAiApp(
      imageSource: FakeImageSource(() async => null),
      projectRepository: FakeProjectRepository(initial: [
        sampleProject(id: 'gato', name: 'gato.png', categoryId: 'c1'),
        sampleProject(
          id: 'rosto',
          name: 'rosto.png',
          categoryId: 'c2',
          updatedAt: DateTime(2025, 3),
        ),
        sampleProject(
          id: 'praia',
          name: 'praia.png',
          categoryId: 'c3',
          updatedAt: DateTime(2025, 2),
        ),
        sampleProject(
          id: 'solto',
          name: 'solto.png',
          updatedAt: DateTime(2025, 1),
        ),
      ]),
      categoryRepository: FakeCategoryRepository(
        initial:
            withCategories ? [_animais, _retratos, _paisagens] : const [],
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

Finder get _selectAll => find.byKey(CategoryFilterScreen.selectAllKey);

/// Texto atual do botão "Aplicar".
String _applyLabel(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(CategoryFilterScreen.applyButtonKey),
        matching: find.byType(Text),
      ),
    )
    .data!;

/// A caixa de marcar da linha de uma categoria (pelo nome).
bool _isChecked(WidgetTester tester, String name) => tester
    .widget<Checkbox>(
      find.descendant(
        of: find.ancestor(
          of: _inPicker(find.text(name)),
          matching: find.byType(ListTile),
        ),
        matching: find.byType(Checkbox),
      ),
    )
    .value!;

Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(_inPicker(find.byType(TextField)), text);
  await tester.pump();
}

void main() {
  group('"Limpar" à esquerda', () {
    testWidgets('Limpar na margem esquerda e Adicionar na direita, separados',
        (tester) async {
      await _openPicker(tester);
      final screen = tester.getSize(find.byType(CategoryFilterScreen));
      final clear =
          tester.getRect(find.byKey(CategoryFilterScreen.clearButtonKey));
      final add = tester.getRect(find.byKey(CategoryFilterScreen.addButtonKey));

      expect(clear.left, closeTo(16, 0.5));
      expect(add.right, closeTo(screen.width - 16, 0.5));
      // Na mesma linha e longe um do outro (não estão colados).
      expect(clear.center.dy, closeTo(add.center.dy, 0.5));
      expect(add.left - clear.right, greaterThanOrEqualTo(16));
    });

    testWidgets('Limpar segue o molde do Adicionar (altura, fonte, recuo)',
        (tester) async {
      await _openPicker(tester);
      final clearFinder = find.byKey(CategoryFilterScreen.clearButtonKey);
      final addFinder = find.byKey(CategoryFilterScreen.addButtonKey);

      // Contornado (ação secundária) ao lado do preenchido (principal).
      expect(tester.widget(clearFinder), isA<OutlinedButton>());
      expect(tester.widget(addFinder), isA<FilledButton>());

      // Mesma altura na tela.
      expect(tester.getSize(clearFinder).height, 56);
      expect(tester.getSize(addFinder).height, 56);

      // Mesmo molde: tamanho mínimo, recuo e fonte iguais.
      final clearStyle = tester.widget<ButtonStyleButton>(clearFinder).style!;
      final addStyle = tester.widget<ButtonStyleButton>(addFinder).style!;
      const states = <WidgetState>{};
      expect(clearStyle.minimumSize!.resolve(states),
          addStyle.minimumSize!.resolve(states));
      expect(clearStyle.padding!.resolve(states),
          addStyle.padding!.resolve(states));
      expect(clearStyle.textStyle!.resolve(states),
          addStyle.textStyle!.resolve(states));
    });

    testWidgets('Limpar continua desmarcando tudo', (tester) async {
      await _openPicker(tester);
      final clear = find.byKey(CategoryFilterScreen.clearButtonKey);
      // Nada marcado: não há o que limpar.
      expect(tester.widget<OutlinedButton>(clear).onPressed, isNull);

      await tester.tap(_inPicker(find.text('Animais')));
      await tester.tap(_inPicker(find.text('Sem categoria')));
      await tester.pump();
      expect(_applyLabel(tester), 'Aplicar (2 selecionadas)');

      await tester.tap(clear);
      await tester.pump();
      expect(_applyLabel(tester), 'Mostrar todos os desenhos');
      expect(_isChecked(tester, 'Animais'), isFalse);
    });
  });

  group('"Selecionar todas"', () {
    testWidgets('fica logo abaixo de "Sem categoria" e antes das categorias',
        (tester) async {
      await _openPicker(tester);
      final uncategorized = tester.getRect(find.ancestor(
        of: _inPicker(find.text('Sem categoria')),
        matching: find.byType(CheckboxListTile),
      ));
      final selectAll = tester.getRect(_selectAll);
      final firstCategory = tester.getRect(_inPicker(find.text('Animais')));

      expect(selectAll.top, closeTo(uncategorized.bottom, 0.5));
      expect(selectAll.bottom, lessThan(firstCategory.top));
      expect(_inPicker(find.text('Selecionar todas')), findsOneWidget);
      expect(_inPicker(find.text('Marca todas as categorias')), findsOneWidget);
    });

    testWidgets('marca TODAS as categorias, sem mexer em "Sem categoria"',
        (tester) async {
      await _openPicker(tester);
      await tester.tap(_selectAll);
      await tester.pump();

      expect(_isChecked(tester, 'Animais'), isTrue);
      expect(_isChecked(tester, 'Retratos'), isTrue);
      expect(_isChecked(tester, 'Paisagens'), isTrue);
      expect(_applyLabel(tester), 'Aplicar (3 selecionadas)');
      // Tudo marcado: o botão fica desabilitado (tocar não faria nada).
      expect(tester.widget<ListTile>(_selectAll).enabled, isFalse);

      // Aplicado, mostra os desenhos das 3 categorias (e não o "solto").
      await tester.tap(find.byKey(CategoryFilterScreen.applyButtonKey));
      await settle(tester);
      final visible = tester
          .widgetList<ProjectHistoryTile>(find.byType(ProjectHistoryTile))
          .map((t) => t.project.id);
      expect(visible, unorderedEquals(['gato', 'rosto', 'praia']));
    });

    testWidgets('com pesquisa: marca só as exibidas e mantém as anteriores',
        (tester) async {
      await _openPicker(tester);
      // "Retratos" marcada ANTES da pesquisa.
      await tester.tap(_inPicker(find.text('Retratos')));
      await tester.pump();

      // "ais" encontra Animais e Paisagens (e esconde Retratos).
      await _search(tester, 'ais');
      expect(_inPicker(find.text('Retratos')), findsNothing);
      expect(
        _inPicker(find.text('Marca as 2 categorias da pesquisa')),
        findsOneWidget,
      );
      await tester.tap(_selectAll);
      await tester.pump();
      expect(_isChecked(tester, 'Animais'), isTrue);
      expect(_isChecked(tester, 'Paisagens'), isTrue);

      // Retratos (escondida pela pesquisa) continua marcada.
      await _search(tester, '');
      expect(_isChecked(tester, 'Retratos'), isTrue);
      expect(_applyLabel(tester), 'Aplicar (3 selecionadas)');
    });

    testWidgets('com pesquisa sem "Retratos" marcada, Retratos fica de fora',
        (tester) async {
      await _openPicker(tester);
      await _search(tester, 'ais');
      await tester.tap(_selectAll);
      await tester.pump();
      await _search(tester, '');
      expect(_isChecked(tester, 'Animais'), isTrue);
      expect(_isChecked(tester, 'Paisagens'), isTrue);
      expect(_isChecked(tester, 'Retratos'), isFalse);
      expect(_applyLabel(tester), 'Aplicar (2 selecionadas)');
    });

    testWidgets('pesquisa com uma categoria usa o singular', (tester) async {
      await _openPicker(tester);
      await _search(tester, 'retr');
      expect(
        _inPicker(find.text('Marca a categoria da pesquisa')),
        findsOneWidget,
      );
    });

    testWidgets('sem categorias exibidas, não aparece', (tester) async {
      await _openPicker(tester, withCategories: false);
      expect(_selectAll, findsNothing);
      // "Sem categoria" continua lá.
      expect(_inPicker(find.text('Sem categoria')), findsOneWidget);
    });

    testWidgets('pesquisa sem resultado esconde o botão', (tester) async {
      await _openPicker(tester);
      await _search(tester, 'zzz');
      expect(_selectAll, findsNothing);
    });
  });
}
