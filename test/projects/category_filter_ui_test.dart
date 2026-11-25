// Fase 5 (Etapa 5B): faixa de categorias abaixo da busca, seletor com
// pesquisa/seleção múltipla/criação/remoção e filtro combinado na Home.
import 'package:desenha_ai/app.dart';
import 'package:desenha_ai/core/widgets/page_header.dart';
import 'package:desenha_ai/features/projects/screens/category_filter_screen.dart';
import 'package:desenha_ai/features/projects/widgets/category_badge.dart';
import 'package:desenha_ai/features/projects/widgets/category_filter_bar.dart';
import 'package:desenha_ai/features/projects/widgets/category_form_dialog.dart';
import 'package:desenha_ai/features/projects/widgets/project_history_tile.dart';
import 'package:desenha_ai/features/projects/widgets/project_search_field.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../fakes.dart';

final _animais = sampleCategory(id: 'c1', name: 'Animais');
final _retratos =
    sampleCategory(id: 'c2', name: 'Retratos', colorValue: 0xFF1E88E5);
final _paisagens =
    sampleCategory(id: 'c3', name: 'Paisagens', colorValue: 0xFFFFB300);

/// Histórico usado na maioria dos testes.
List<_Item> get _items => [
      _Item('gato', 'gato.png', 'c1', DateTime(2025, 5)),
      _Item('cao', 'cão.png', 'c1', DateTime(2025, 4)),
      _Item('rosto', 'rosto gato.png', 'c2', DateTime(2025, 3)),
      _Item('solto', 'gato solto.png', null, DateTime(2025, 2)),
    ];

class _Item {
  _Item(this.id, this.name, this.categoryId, this.updatedAt);
  final String id;
  final String name;
  final String? categoryId;
  final DateTime updatedAt;
}

Future<({FakeProjectRepository projects, FakeCategoryRepository categories})>
    _pumpHome(
  WidgetTester tester, {
  List<_Item>? items,
  bool withCategories = true,
}) async {
  // Tela alta (como um tablet em pé): a lista é preguiçosa e só constrói
  // os cards visíveis. Na tela padrão de teste (800x600), o 4º card ficaria
  // fora da área visível e não seria contado.
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final projects = FakeProjectRepository(initial: [
    for (final i in items ?? _items)
      sampleProject(
        id: i.id,
        name: i.name,
        categoryId: i.categoryId,
        updatedAt: i.updatedAt,
      ),
  ]);
  final categories = FakeCategoryRepository(
    initial: withCategories ? [_animais, _retratos, _paisagens] : const [],
  );
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
  return (projects: projects, categories: categories);
}

List<String> _visible(WidgetTester tester) => tester
    .widgetList<ProjectHistoryTile>(find.byType(ProjectHistoryTile))
    .map((t) => t.project.id)
    .toList();

Finder _topSearch() => find.descendant(
      of: find.byType(ProjectSearchField),
      matching: find.byType(TextField),
    );

Finder _inPicker(Finder finder) =>
    find.descendant(of: find.byType(CategoryFilterScreen), matching: finder);

Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Pesquisar e criar categorias'));
  await settle(tester);
  expect(find.byType(CategoryFilterScreen), findsOneWidget);
}

/// Linha de uma categoria (ou de "Sem categoria") no seletor.
Future<void> _toggleInPicker(WidgetTester tester, String name) async {
  await tester.tap(_inPicker(find.text(name)));
  await tester.pump();
}

Future<void> _apply(WidgetTester tester) async {
  await tester.tap(find.byKey(CategoryFilterScreen.applyButtonKey));
  await settle(tester);
}

void main() {
  group('faixa abaixo da busca', () {
    testWidgets('mostra "Sem categoria" neutra e o botão ao lado',
        (tester) async {
      await _pumpHome(tester, withCategories: false);

      final bar = find.byType(CategoryFilterBar);
      expect(bar, findsOneWidget);
      final chip = find.descendant(
        of: bar,
        matching: find.widgetWithText(FilterChip, 'Sem categoria'),
      );
      expect(chip, findsOneWidget);
      expect(find.byTooltip('Pesquisar e criar categorias'), findsOneWidget);

      // Abaixo da barra de pesquisa...
      expect(
        tester.getTopLeft(bar).dy,
        greaterThan(tester.getBottomLeft(_topSearch()).dy),
      );
      // ...e o botão fica ao lado (mesma linha, à direita) da etiqueta.
      final chipBox = tester.getRect(chip);
      final button = tester.getRect(find.byTooltip('Pesquisar e criar categorias'));
      expect(button.left, greaterThan(chipBox.right));
      expect(button.center.dy, closeTo(chipBox.center.dy, 4));

      // Visual neutro: sem bolinha de cor de categoria, desmarcada.
      expect(
        find.descendant(of: chip, matching: find.byType(CategoryColorDot)),
        findsNothing,
      );
      expect(tester.widget<FilterChip>(chip).selected, isFalse);
      // E, sem filtro, todos os desenhos continuam aparecendo.
      expect(_visible(tester), hasLength(4));
    });

    testWidgets('tocar "Sem categoria" na faixa filtra os sem categoria',
        (tester) async {
      await _pumpHome(tester);
      await tester.tap(find.widgetWithText(FilterChip, 'Sem categoria'));
      await tester.pump();
      expect(_visible(tester), ['solto']);

      await tester.tap(find.widgetWithText(FilterChip, 'Sem categoria'));
      await tester.pump();
      expect(_visible(tester), hasLength(4));
    });

    testWidgets('categorias marcadas aparecem na faixa e saem pelo "×"',
        (tester) async {
      await _pumpHome(tester);
      await _openPicker(tester);
      await _toggleInPicker(tester, 'Animais');
      await _toggleInPicker(tester, 'Retratos');
      await _apply(tester);

      final bar = find.byType(CategoryFilterBar);
      expect(
        find.descendant(of: bar, matching: find.widgetWithText(InputChip, 'Animais')),
        findsOneWidget,
      );
      expect(find.text('Categorias (2)'), findsOneWidget);
      expect(_visible(tester), ['gato', 'cao', 'rosto']);

      await tester.tap(find.byTooltip('Tirar "Animais" do filtro'));
      await tester.pump();
      expect(_visible(tester), ['rosto']);
      expect(find.text('Categorias (1)'), findsOneWidget);
    });
  });

  group('seletor de categorias', () {
    testWidgets('pesquisa as categorias em tempo real', (tester) async {
      await _pumpHome(tester);
      await _openPicker(tester);
      expect(_inPicker(find.text('Paisagens')), findsOneWidget);

      await tester.enterText(_inPicker(find.byType(TextField)), 'RETR');
      await tester.pump();
      expect(_inPicker(find.text('Retratos')), findsOneWidget);
      expect(_inPicker(find.text('Animais')), findsNothing);
      expect(_inPicker(find.text('Paisagens')), findsNothing);
      expect(_inPicker(find.text('Sem categoria')), findsNothing);

      // "sem" também encontra a opção neutra.
      await tester.enterText(_inPicker(find.byType(TextField)), 'sem');
      await tester.pump();
      expect(_inPicker(find.text('Sem categoria')), findsOneWidget);
    });

    testWidgets('seleção múltipla com "Sem categoria" junto', (tester) async {
      await _pumpHome(tester);
      await _openPicker(tester);
      await _toggleInPicker(tester, 'Retratos');
      await _toggleInPicker(tester, 'Sem categoria');
      expect(_inPicker(find.text('Aplicar (2 selecionadas)')), findsOneWidget);
      await _apply(tester);

      expect(_visible(tester), ['rosto', 'solto']);
      final chip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Sem categoria'),
      );
      expect(chip.selected, isTrue);
    });

    testWidgets('fechar no "X" não muda o filtro', (tester) async {
      await _pumpHome(tester);
      await _openPicker(tester);
      await _toggleInPicker(tester, 'Animais');
      // Etapa 6F: a seta de voltar substituiu o "X".
      await tester.tap(_inPicker(find.byKey(PageHeader.backButtonKey)));
      await settle(tester);

      expect(_visible(tester), hasLength(4));
      // O chip da faixa continua sem contador. (Pelo tipo: o título
      // "Categorias" acima da faixa tem o mesmo texto.)
      expect(find.widgetWithText(ActionChip, 'Categorias'), findsOneWidget);
    });

    testWidgets('"Limpar" desmarca tudo e mostra todos ao aplicar',
        (tester) async {
      await _pumpHome(tester);
      await _openPicker(tester);
      await _toggleInPicker(tester, 'Animais');
      await _apply(tester);
      expect(_visible(tester), ['gato', 'cao']);

      await _openPicker(tester);
      await tester.tap(_inPicker(find.text('Limpar')));
      await tester.pump();
      expect(_inPicker(find.text('Mostrar todos os desenhos')), findsOneWidget);
      await _apply(tester);
      expect(_visible(tester), hasLength(4));
    });

    testWidgets('cria categoria pela pesquisa ("Criar categoria “x”")',
        (tester) async {
      final repos = await _pumpHome(tester);
      await _openPicker(tester);

      await tester.enterText(_inPicker(find.byType(TextField)), 'Flores');
      await tester.pump();
      await tester.tap(_inPicker(find.text('Criar categoria “Flores”')));
      await settle(tester);

      // O formulário abre com o nome já preenchido.
      final nameField = find.descendant(
        of: find.byType(CategoryFormDialog),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(nameField).controller!.text, 'Flores');
      await tester.tap(find.byTooltip('Cor: Rosa'));
      await tester.tap(find.text('Criar'));
      await settle(tester);

      final created = (await repos.categories.listAll())
          .singleWhere((c) => c.name == 'Flores');
      expect(created.colorValue, 0xFFD81B60);
      // A pesquisa foi limpa e a categoria nova aparece na lista.
      expect(_inPicker(find.text('Flores')), findsOneWidget);
      expect(_inPicker(find.text('Animais')), findsOneWidget);
    });

    testWidgets('nome que já existe não oferece "Criar"', (tester) async {
      await _pumpHome(tester);
      await _openPicker(tester);
      await tester.enterText(_inPicker(find.byType(TextField)), 'animais');
      await tester.pump();
      expect(_inPicker(find.textContaining('Criar categoria')), findsNothing);
    });

    testWidgets('remove categoria (com confirmação) e limpa vínculos e filtro',
        (tester) async {
      final repos = await _pumpHome(tester);
      await _openPicker(tester);
      await _toggleInPicker(tester, 'Animais');

      await tester.enterText(_inPicker(find.byType(TextField)), 'anim');
      await tester.pump();
      await tester.tap(_inPicker(find.byTooltip('Remover categoria')));
      await settle(tester);
      expect(find.text('Remover categoria?'), findsOneWidget);
      await tester.tap(find.text('Remover'));
      await settle(tester);

      expect(repos.categories.deleted, ['c1']);
      expect(repos.projects['gato']!.categoryId, isNull);
      expect(repos.projects['cao']!.categoryId, isNull);
      expect(
        find.text('Categoria removida. 2 desenhos ficaram sem categoria.'),
        findsOneWidget,
      );
      // A categoria removida saiu da seleção.
      expect(
        _inPicker(find.text('Mostrar todos os desenhos')),
        findsOneWidget,
      );

      await _apply(tester);
      // Na Home: gato e cão agora estão sem categoria (sem badge).
      expect(_visible(tester), hasLength(4));
      expect(find.byType(CategoryBadge), findsOneWidget); // só "rosto"
    });

    testWidgets('sem categorias, o seletor explica como criar',
        (tester) async {
      await _pumpHome(tester, withCategories: false);
      await _openPicker(tester);
      expect(
        _inPicker(find.textContaining('Você ainda não criou categorias')),
        findsOneWidget,
      );
      expect(_inPicker(find.text('Sem categoria')), findsOneWidget);
    });

    testWidgets('fechar o seletor descarta controller e foco sem erros',
        (tester) async {
      await _pumpHome(tester);
      await _openPicker(tester);
      await tester.enterText(_inPicker(find.byType(TextField)), 'x');
      await tester.tap(_inPicker(find.byKey(PageHeader.backButtonKey)));
      await settle(tester);
      expect(find.byType(CategoryFilterScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('filtro combinado com a busca do topo', () {
    testWidgets('com categoria marcada, a busca procura só dentro dela',
        (tester) async {
      await _pumpHome(tester);
      await _openPicker(tester);
      await _toggleInPicker(tester, 'Animais');
      await _apply(tester);

      // "gato" está em 3 desenhos, mas só 1 é de Animais.
      await tester.enterText(_topSearch(), 'gato');
      await tester.pump();
      expect(_visible(tester), ['gato']);

      await tester.enterText(_topSearch(), 'rosto');
      await tester.pump();
      expect(_visible(tester), isEmpty);
      expect(
        find.text(
          'Nenhum desenho encontrado para “rosto” com os filtros '
          'selecionados.',
        ),
        findsOneWidget,
      );

      // Limpar a busca volta a mostrar todos de Animais.
      await tester.tap(find.byTooltip('Limpar pesquisa'));
      await tester.pump();
      expect(_visible(tester), ['gato', 'cao']);
    });

    testWidgets('com "Sem categoria", a busca funciona sobre esses itens',
        (tester) async {
      await _pumpHome(tester, items: [
        ..._items,
        _Item('orfao', 'gato órfão.png', 'apagada', DateTime(2025, 1)),
      ]);
      await tester.tap(find.widgetWithText(FilterChip, 'Sem categoria'));
      await tester.pump();
      // Inclui o desenho cuja categoria foi apagada.
      expect(_visible(tester), ['solto', 'orfao']);

      await tester.enterText(_topSearch(), 'orfao');
      await tester.pump();
      expect(_visible(tester), ['orfao']);
    });

    testWidgets('filtro sem nenhum desenho mostra mensagem clara',
        (tester) async {
      await _pumpHome(tester);
      await _openPicker(tester);
      await _toggleInPicker(tester, 'Paisagens'); // nenhum desenho
      await _apply(tester);

      expect(_visible(tester), isEmpty);
      expect(
        find.text('Nenhum desenho com os filtros selecionados.'),
        findsOneWidget,
      );
    });

    testWidgets('trocar a categoria de um desenho atualiza o filtro na hora',
        (tester) async {
      await _pumpHome(tester);
      await _openPicker(tester);
      await _toggleInPicker(tester, 'Retratos');
      await _apply(tester);
      expect(_visible(tester), ['rosto']);

      // Move "rosto" para "Sem categoria" pelo Editar: sai do filtro.
      await tester.tap(find.byTooltip('Editar desenho'));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Sem categoria'),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Salvar'));
      await settle(tester);

      expect(_visible(tester), isEmpty);
    });
  });
}
