// Status dos desenhos na Home (etapa final): botão no card, diálogo, badge,
// filtro direto entre a busca e as categorias, e combinação com busca e
// categorias. Tudo com os fakes de test/fakes.dart.
import 'package:desenha_ai/app.dart';
import 'package:desenha_ai/features/drawing/screens/drawing_screen.dart';
import 'package:desenha_ai/features/image_selection/data/local_image_source.dart';
import 'package:desenha_ai/features/projects/models/drawing_project.dart';
import 'package:desenha_ai/features/projects/models/project_status.dart';
import 'package:desenha_ai/features/projects/widgets/category_badge.dart';
import 'package:desenha_ai/features/projects/widgets/category_filter_bar.dart';
import 'package:desenha_ai/features/projects/widgets/project_history_list.dart';
import 'package:desenha_ai/features/projects/widgets/project_history_tile.dart';
import 'package:desenha_ai/features/projects/widgets/project_search_field.dart';
import 'package:desenha_ai/features/projects/widgets/project_status_badge.dart';
import 'package:desenha_ai/features/projects/widgets/project_status_dialog.dart';
import 'package:desenha_ai/features/projects/widgets/status_filter_bar.dart';
import 'package:desenha_ai/features/theme/app_palette.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../fakes.dart';

final _animais = sampleCategory(id: 'c1', name: 'Animais');

/// Histórico usado na maioria dos testes (do mais recente ao mais antigo).
List<DrawingProject> get _defaultProjects => [
      sampleProject(
        id: 'gato',
        name: 'gato.png',
        categoryId: 'c1',
        updatedAt: DateTime(2025, 6),
      ),
      sampleProject(id: 'casa', name: 'casa.png', updatedAt: DateTime(2025, 5)),
      sampleProject(
        id: 'rosto',
        name: 'gato rosto.png',
        status: ProjectStatus.inProgress,
        updatedAt: DateTime(2025, 4),
      ),
      sampleProject(
        id: 'flor',
        name: 'flor.png',
        categoryId: 'c1',
        status: ProjectStatus.done,
        updatedAt: DateTime(2025, 3),
      ),
      sampleProject(
        id: 'velho',
        name: 'gato velho.png',
        categoryId: 'c1',
        status: ProjectStatus.archived,
        updatedAt: DateTime(2025, 2),
      ),
    ];

Future<FakeProjectRepository> _pumpHome(
  WidgetTester tester, {
  FakeProjectRepository? repository,
  FakeImageSource? source,
  Size size = const Size(1000, 1800),
}) async {
  // Tela alta: a lista é preguiçosa e só constrói os cards visíveis.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final theme = fakeThemeController();
  addTearDown(theme.dispose);
  final repo = repository ?? FakeProjectRepository(initial: _defaultProjects);
  await tester.pumpWidget(
    DesenhaAiApp(
      imageSource: source ?? FakeImageSource(() async => null),
      projectRepository: repo,
      categoryRepository: FakeCategoryRepository(initial: [_animais]),
      cameraServiceFactory: FakeCameraService.new,
      screenWakeLock: FakeScreenWakeLock(),
      themeController: theme,
    ),
  );
  await tester.pump();
  return repo;
}

List<String> _visible(WidgetTester tester) => tester
    .widgetList<ProjectHistoryTile>(find.byType(ProjectHistoryTile))
    .map((t) => t.project.id)
    .toList();

Finder _tile(String name) => find.widgetWithText(ProjectHistoryTile, name);

Finder _inTile(String name, Finder f) =>
    find.descendant(of: _tile(name), matching: f);

Finder _chip(ProjectStatus s) => find.byKey(StatusFilterBar.chipKey(s));

bool _chipSelected(WidgetTester tester, ProjectStatus s) => tester
    .widget<FilterChip>(
      find.descendant(of: _chip(s), matching: find.byType(FilterChip)),
    )
    .selected;

Finder get _allChip => find.byKey(StatusFilterBar.allChipKey);

bool _allSelected(WidgetTester tester) =>
    tester.widget<FilterChip>(
      find.descendant(of: _allChip, matching: find.byType(FilterChip)),
    ).selected;

/// Quais dos 4 status específicos estão marcados.
Set<ProjectStatus> _selectedStatuses(WidgetTester tester) => {
      for (final s in ProjectStatus.values)
        if (_chipSelected(tester, s)) s,
    };

Future<void> _tapAll(WidgetTester tester) async {
  await tester.tap(_allChip);
  await tester.pump();
}

Future<void> _toggleChip(WidgetTester tester, ProjectStatus s) async {
  await tester.tap(_chip(s));
  await tester.pump();
}

ProjectStatus _badgeStatus(WidgetTester tester, String name) => tester
    .widget<ProjectStatusBadge>(_inTile(name, find.byType(ProjectStatusBadge)))
    .status;

Future<void> _chooseStatus(
  WidgetTester tester,
  String name,
  ProjectStatus status,
) async {
  await tester.tap(_inTile(name, find.byTooltip('Alterar status')));
  await settle(tester);
  await tester.tap(find.byKey(ProjectStatusDialog.optionKey(status)));
  await settle(tester);
}

void main() {
  group('botão de status no card', () {
    testWidgets('fica à esquerda do Editar, que fica à esquerda do Excluir',
        (tester) async {
      await _pumpHome(tester);
      final status =
          tester.getCenter(_inTile('gato.png', find.byTooltip('Alterar status')));
      final edit =
          tester.getCenter(_inTile('gato.png', find.byTooltip('Editar desenho')));
      final delete = tester
          .getCenter(_inTile('gato.png', find.byTooltip('Excluir desenho')));

      expect(status.dx, lessThan(edit.dx));
      expect(edit.dx, lessThan(delete.dx));
      expect(status.dy, closeTo(edit.dy, 1)); // mesma linha
      expect(_inTile('gato.png', find.byIcon(Icons.flag_outlined)),
          findsOneWidget);
    });

    testWidgets('abre o diálogo com os 4 status, o atual marcado',
        (tester) async {
      await _pumpHome(tester);
      await tester.tap(_inTile('gato.png', find.byTooltip('Alterar status')));
      await settle(tester);

      expect(find.byType(ProjectStatusDialog), findsOneWidget);
      expect(find.text('Status do desenho'), findsOneWidget);
      for (final s in ProjectStatus.values) {
        final option = find.byKey(ProjectStatusDialog.optionKey(s));
        expect(option, findsOneWidget);
        expect(find.descendant(of: option, matching: find.text(s.label)),
            findsOneWidget);
        expect(find.descendant(of: option, matching: find.byType(Icon)),
            findsWidgets);
      }
      // O atual ("Não iniciado") tem o "check".
      expect(
        find.descendant(
          of: find.byKey(
              ProjectStatusDialog.optionKey(ProjectStatus.notStarted)),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
    });

    testWidgets('escolher salva NA HORA e atualiza a badge do card',
        (tester) async {
      // Com "Todos" (padrão), o card continua visível depois da troca.
      final repo = await _pumpHome(tester);
      expect(_badgeStatus(tester, 'gato.png'), ProjectStatus.notStarted);

      await _chooseStatus(tester, 'gato.png', ProjectStatus.done);

      expect(find.byType(ProjectStatusDialog), findsNothing);
      expect(repo.statusChanges,
          [(id: 'gato', status: ProjectStatus.done)]);
      expect(repo['gato']!.status, ProjectStatus.done);
      expect(_badgeStatus(tester, 'gato.png'), ProjectStatus.done);
      expect(_inTile('gato.png', find.text('Concluído')), findsOneWidget);
      expect(find.text('Status alterado para "Concluído".'), findsOneWidget);
      // Mudar o status não mexe na ordem nem no "último acesso".
      expect(repo['gato']!.updatedAt, DateTime(2025, 6));
      expect(_visible(tester).first, 'gato');
    });

    testWidgets('status fora do filtro: o card sai e a mensagem explica',
        (tester) async {
      await _pumpHome(tester);
      await _toggleChip(tester, ProjectStatus.notStarted);
      expect(_visible(tester), ['gato', 'casa']);

      await _chooseStatus(tester, 'gato.png', ProjectStatus.archived);

      expect(_visible(tester), ['casa']);
      expect(
        find.text('Status alterado para "Arquivado". O desenho saiu da lista '
            'porque esse status não está marcado no filtro.'),
        findsOneWidget,
      );
    });

    testWidgets('cancelar ou escolher o mesmo status não grava',
        (tester) async {
      final repo = await _pumpHome(tester);
      await tester.tap(_inTile('gato.png', find.byTooltip('Alterar status')));
      await settle(tester);
      await tester.tap(find.text('Cancelar'));
      await settle(tester);

      await _chooseStatus(tester, 'gato.png', ProjectStatus.notStarted);

      expect(repo.statusChanges, isEmpty);
      expect(find.byType(ProjectStatusDialog), findsNothing);
    });
  });

  group('badge de status no card', () {
    testWidgets('fica à ESQUERDA da categoria, na mesma linha',
        (tester) async {
      await _pumpHome(tester);
      final status =
          tester.getRect(_inTile('gato.png', find.byType(ProjectStatusBadge)));
      final category =
          tester.getRect(_inTile('gato.png', find.byType(CategoryBadge)));

      expect(status.right, lessThanOrEqualTo(category.left));
      expect(status.center.dy, closeTo(category.center.dy, 1));
      expect(_inTile('gato.png', find.text('Não iniciado')), findsOneWidget);
      expect(_inTile('gato.png', find.byIcon(Icons.radio_button_unchecked)),
          findsOneWidget);
    });

    testWidgets('sem categoria, a badge de status aparece sozinha',
        (tester) async {
      await _pumpHome(tester);
      expect(_inTile('casa.png', find.byType(ProjectStatusBadge)),
          findsOneWidget);
      expect(_inTile('casa.png', find.byType(CategoryBadge)), findsNothing);
    });

    testWidgets('modo escuro usa o tom claro da cor do status',
        (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await _pumpHome(tester);
      await tester.pump(const Duration(milliseconds: 500));

      final icon = tester.widget<Icon>(_inTile(
        'gato.png',
        find.descendant(
          of: find.byType(ProjectStatusBadge),
          matching: find.byType(Icon),
        ),
      ));
      expect(icon.color, AppPalette.statusNotStartedDark);
    });

    testWidgets('celular em pé (360 dp): três botões e duas badges, sem '
        'overflow', (tester) async {
      await _pumpHome(tester, size: const Size(360, 1400));
      expect(_inTile('gato.png', find.byType(ProjectStatusBadge)),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('filtro de status', () {
    testWidgets('fica ENTRE a barra de pesquisa e as categorias',
        (tester) async {
      await _pumpHome(tester);
      final search = tester.getRect(find.byType(ProjectSearchField));
      final status = tester.getRect(find.byType(StatusFilterBar));
      final categories = tester.getRect(find.byType(CategoryFilterBar));

      expect(search.bottom, lessThanOrEqualTo(status.top));
      expect(status.bottom, lessThanOrEqualTo(categories.top));
    });

    testWidgets('mostra os 4 status direto na tela (ícone + nome), sem modal',
        (tester) async {
      await _pumpHome(tester);
      for (final s in ProjectStatus.values) {
        expect(_chip(s), findsOneWidget);
        expect(find.descendant(of: _chip(s), matching: find.text(s.label)),
            findsOneWidget);
        expect(find.descendant(of: _chip(s), matching: find.byType(Icon)),
            findsOneWidget);
      }
      // Tocar num chip não abre nada: só marca.
      await _toggleChip(tester, ProjectStatus.done);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('começa com os 4 específicos desmarcados', (tester) async {
      await _pumpHome(tester);
      for (final s in ProjectStatus.values) {
        expect(_chipSelected(tester, s), isFalse, reason: s.label);
      }
      expect(_visible(tester), hasLength(5));
    });

    testWidgets('marcar vários soma; desmarcar todos mostra todos',
        (tester) async {
      await _pumpHome(tester);
      await _toggleChip(tester, ProjectStatus.notStarted);
      expect(_visible(tester), ['gato', 'casa']);
      await _toggleChip(tester, ProjectStatus.inProgress);
      await _toggleChip(tester, ProjectStatus.done);
      expect(_visible(tester), ['gato', 'casa', 'rosto', 'flor']);

      await _toggleChip(tester, ProjectStatus.notStarted);
      expect(_visible(tester), ['rosto', 'flor']);

      await _toggleChip(tester, ProjectStatus.inProgress);
      await _toggleChip(tester, ProjectStatus.done);
      expect(_visible(tester), ['gato', 'casa', 'rosto', 'flor', 'velho']);
      // E nesse caso "Todos" aparece marcado.
      expect(_allSelected(tester), isTrue);
    });

    testWidgets('funciona junto com a busca do topo', (tester) async {
      await _pumpHome(tester);
      // Não iniciado + Arquivado.
      await _toggleChip(tester, ProjectStatus.notStarted);
      await _toggleChip(tester, ProjectStatus.archived);
      await tester.enterText(
        find.descendant(
          of: find.byType(ProjectSearchField),
          matching: find.byType(TextField),
        ),
        'gato',
      );
      await tester.pump();
      // "gato rosto" (Em andamento) fica de fora.
      expect(_visible(tester), ['gato', 'velho']);
    });

    testWidgets('funciona junto com categorias e busca ao mesmo tempo',
        (tester) async {
      await _pumpHome(tester);
      // Status: Não iniciado + Em andamento.
      await _toggleChip(tester, ProjectStatus.notStarted);
      await _toggleChip(tester, ProjectStatus.inProgress);
      expect(_visible(tester), ['gato', 'casa', 'rosto']);

      // Categoria: só "Sem categoria".
      await tester.tap(find.widgetWithText(FilterChip, 'Sem categoria'));
      await tester.pump();
      expect(_visible(tester), ['casa', 'rosto']);

      // Busca: "gato".
      await tester.enterText(
        find.descendant(
          of: find.byType(ProjectSearchField),
          matching: find.byType(TextField),
        ),
        'gato',
      );
      await tester.pump();
      expect(_visible(tester), ['rosto']);

      // Busca que existe, mas fora dos filtros: a mensagem diz isso.
      await tester.enterText(
        find.descendant(
          of: find.byType(ProjectSearchField),
          matching: find.byType(TextField),
        ),
        'flor',
      );
      await tester.pump();
      expect(_visible(tester), isEmpty);
      expect(
        find.text('Nenhum desenho encontrado para “flor” com os filtros '
            'selecionados.'),
        findsOneWidget,
      );
    });

    testWidgets('só os filtros esvaziam a lista: mensagem clara',
        (tester) async {
      final repo = FakeProjectRepository(initial: [
        sampleProject(id: 'a', name: 'a.png', status: ProjectStatus.done),
      ]);
      await _pumpHome(tester, repository: repo);
      expect(_visible(tester), ['a']); // "Todos": aparece
      await _toggleChip(tester, ProjectStatus.notStarted);
      expect(_visible(tester), isEmpty);
      expect(find.text('Nenhum desenho com os filtros selecionados.'),
          findsOneWidget);
    });
  });

  group('títulos dos filtros', () {
    // As chaves ficam no título, que é um SLIVER (não tem retângulo para
    // medir). Medimos o texto dentro dele.
    Finder statusLabel() => find.descendant(
          of: find.byKey(ProjectHistoryList.statusLabelKey),
          matching: find.byType(Text),
        );
    Finder categoriesLabel() => find.descendant(
          of: find.byKey(ProjectHistoryList.categoriesLabelKey),
          matching: find.byType(Text),
        );

    testWidgets('"Status dos desenhos" entre a pesquisa e os chips de status',
        (tester) async {
      await _pumpHome(tester);
      expect(tester.widget<Text>(statusLabel()).data, 'Status dos desenhos');

      final search = tester.getRect(find.byType(ProjectSearchField));
      final label = tester.getRect(statusLabel());
      final chips = tester.getRect(find.byType(StatusFilterBar));
      expect(search.bottom, lessThanOrEqualTo(label.top));
      expect(label.bottom, lessThanOrEqualTo(chips.top));
      // Alinhado à esquerda com os chips.
      expect(label.left, closeTo(chips.left, 0.5));
    });

    testWidgets('"Categorias" entre os chips de status e a faixa de '
        'categorias', (tester) async {
      await _pumpHome(tester);
      expect(tester.widget<Text>(categoriesLabel()).data, 'Categorias');

      final chips = tester.getRect(find.byType(StatusFilterBar));
      final label = tester.getRect(categoriesLabel());
      final categories = tester.getRect(find.byType(CategoryFilterBar));
      expect(chips.bottom, lessThanOrEqualTo(label.top));
      expect(label.bottom, lessThanOrEqualTo(categories.top));
      expect(label.left, closeTo(categories.left, 0.5));
    });

    testWidgets('espaço equilibrado: título colado ao seu filtro', (tester) async {
      await _pumpHome(tester);
      final statusLabelRect = tester.getRect(statusLabel());
      final chips = tester.getRect(find.byType(StatusFilterBar));
      final categoriesLabelRect = tester.getRect(categoriesLabel());
      final categories = tester.getRect(find.byType(CategoryFilterBar));
      // O título fica mais perto do SEU filtro do que do bloco de cima, para
      // a leitura agrupar "título + chips".
      expect(chips.top - statusLabelRect.bottom, lessThanOrEqualTo(8));
      expect(categories.top - categoriesLabelRect.bottom, lessThanOrEqualTo(8));
      expect(categoriesLabelRect.top - chips.bottom, greaterThanOrEqualTo(8));
    });

    testWidgets('títulos são cabeçalhos para o leitor de tela',
        (tester) async {
      await _pumpHome(tester);
      for (final (key, title) in [
        (ProjectHistoryList.statusLabelKey, 'Status dos desenhos'),
        (ProjectHistoryList.categoriesLabelKey, 'Categorias'),
      ]) {
        expect(
          find.ancestor(
            of: find.descendant(
              of: find.byKey(key),
              matching: find.text(title),
            ),
            matching: find.byWidgetPredicate(
              (w) => w is Semantics && (w.properties.header ?? false),
            ),
          ),
          findsOneWidget,
          reason: title,
        );
      }
    });

    testWidgets('modo escuro: títulos legíveis, sem overflow',
        (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await _pumpHome(tester, size: const Size(360, 1400));
      await tester.pump(const Duration(milliseconds: 500));

      final text = tester.widget<Text>(find.text('Status dos desenhos'));
      final scheme = Theme.of(tester.element(statusLabel())).colorScheme;
      expect(text.style?.color, scheme.onSurfaceVariant);
      expect(Theme.of(tester.element(statusLabel())).brightness,
          Brightness.dark);
      expect(tester.takeException(), isNull);
    });
  });

  group('chip "Todos"', () {
    testWidgets('fica imediatamente à esquerda de "Não iniciado"',
        (tester) async {
      await _pumpHome(tester);
      final all = tester.getRect(_allChip);
      final notStarted = tester.getRect(_chip(ProjectStatus.notStarted));

      expect(all.right, lessThanOrEqualTo(notStarted.left));
      // Só o espaçamento da faixa (6 dp) entre os dois: nada no meio.
      expect(notStarted.left - all.right, closeTo(6, 0.5));
      expect(all.center.dy, closeTo(notStarted.center.dy, 0.5));
      // É o primeiro da faixa.
      final bar = tester.getRect(find.byType(StatusFilterBar));
      expect(all.left, closeTo(bar.left, 0.5));
    });

    testWidgets('mesmo molde dos status: ícone + nome', (tester) async {
      await _pumpHome(tester);
      expect(find.descendant(of: _allChip, matching: find.text('Todos')),
          findsOneWidget);
      expect(
        find.descendant(
            of: _allChip, matching: find.byIcon(Icons.all_inclusive)),
        findsOneWidget,
      );
      // Mesma altura dos chips de status.
      expect(tester.getSize(_allChip).height,
          tester.getSize(_chip(ProjectStatus.notStarted)).height);
    });

    testWidgets('ao abrir: "Todos" marcado e nenhum específico',
        (tester) async {
      await _pumpHome(tester);
      expect(_allSelected(tester), isTrue);
      expect(_selectedStatuses(tester), isEmpty);
      // Todos os desenhos à vista logo de entrada, de qualquer status.
      expect(_visible(tester), ['gato', 'casa', 'rosto', 'flor', 'velho']);
    });

    testWidgets('tocar em "Todos" desmarca os específicos e mostra todos',
        (tester) async {
      await _pumpHome(tester);
      await _toggleChip(tester, ProjectStatus.notStarted);
      await _toggleChip(tester, ProjectStatus.done);
      expect(_selectedStatuses(tester),
          {ProjectStatus.notStarted, ProjectStatus.done});
      expect(_visible(tester), ['gato', 'casa', 'flor']);

      await _tapAll(tester);

      expect(_allSelected(tester), isTrue);
      expect(_selectedStatuses(tester), isEmpty);
      expect(_visible(tester), ['gato', 'casa', 'rosto', 'flor', 'velho']);
    });

    testWidgets('tocar em "Todos" já marcado mantém tudo como está',
        (tester) async {
      await _pumpHome(tester);
      await _tapAll(tester);
      await _tapAll(tester);
      expect(_allSelected(tester), isTrue);
      expect(_visible(tester), hasLength(5));
    });

    testWidgets('marcar um status específico desmarca "Todos" sozinho',
        (tester) async {
      await _pumpHome(tester);
      await _tapAll(tester);
      expect(_allSelected(tester), isTrue);

      await _toggleChip(tester, ProjectStatus.archived);

      expect(_allSelected(tester), isFalse);
      expect(_selectedStatuses(tester), {ProjectStatus.archived});
      expect(_visible(tester), ['velho']);
    });

    testWidgets('desmarcar o último específico marca "Todos" sozinho',
        (tester) async {
      await _pumpHome(tester);
      // Marca só "Não iniciado" e depois o desmarca: era o último.
      await _toggleChip(tester, ProjectStatus.notStarted);
      expect(_allSelected(tester), isFalse);
      expect(_visible(tester), ['gato', 'casa']);

      await _toggleChip(tester, ProjectStatus.notStarted);

      expect(_allSelected(tester), isTrue);
      expect(_selectedStatuses(tester), isEmpty);
      expect(_visible(tester), hasLength(5));
    });

    testWidgets('com dois marcados, tirar um NÃO marca "Todos"',
        (tester) async {
      await _pumpHome(tester);
      await _toggleChip(tester, ProjectStatus.done);
      await _toggleChip(tester, ProjectStatus.archived);
      await _toggleChip(tester, ProjectStatus.archived);

      expect(_allSelected(tester), isFalse);
      expect(_selectedStatuses(tester), {ProjectStatus.done});
      expect(_visible(tester), ['flor']);
    });

    testWidgets('"Todos" continua combinando com categoria e busca',
        (tester) async {
      await _pumpHome(tester);
      await _tapAll(tester);
      // "Sem categoria" é o chip de categoria sempre visível na faixa.
      await tester.tap(find.widgetWithText(FilterChip, 'Sem categoria'));
      await tester.pump();
      expect(_visible(tester), ['casa', 'rosto']);

      await tester.enterText(
        find.descendant(
          of: find.byType(ProjectSearchField),
          matching: find.byType(TextField),
        ),
        'gato',
      );
      await tester.pump();
      expect(_visible(tester), ['rosto']);
    });

    testWidgets('celular em pé (360 dp): 5 chips sem overflow',
        (tester) async {
      await _pumpHome(tester, size: const Size(360, 1400));
      expect(_allChip, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('controle 100% manual', () {
    testWidgets('abrir e fechar o desenho NÃO muda o status',
        (tester) async {
      final repo = await _pumpHome(tester);
      await _toggleChip(tester, ProjectStatus.inProgress);

      await tester.tap(find.text('gato rosto.png'));
      await settle(tester);
      expect(find.byType(DrawingScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Voltar'));
      await settle(tester);

      expect(repo.statusChanges, isEmpty);
      expect(repo['rosto']!.status, ProjectStatus.inProgress);
      expect(repo['gato']!.status, ProjectStatus.notStarted);
      expect(_badgeStatus(tester, 'gato rosto.png'), ProjectStatus.inProgress);
    });

    testWidgets('imagem nova entra como "Não iniciado" e aparece mesmo com '
        'outro status filtrado', (tester) async {
      final source = FakeImageSource(
        () async => PickedImage(name: 'nova.png', bytes: pngBytes),
      );
      final repo = await _pumpHome(tester, source: source);
      // Deixa só "Concluído" marcado.
      await _toggleChip(tester, ProjectStatus.done);
      expect(_visible(tester), ['flor']);

      await tester.tap(find.text('Novo desenho'));
      await settle(tester);

      final created = (await repo.listRecent())
          .singleWhere((p) => p.originalName == 'nova.png');
      expect(created.status, ProjectStatus.notStarted);
      // "Não iniciado" voltou a ser marcado, sem desmarcar "Concluído".
      expect(_chipSelected(tester, ProjectStatus.notStarted), isTrue);
      expect(_chipSelected(tester, ProjectStatus.done), isTrue);
      expect(_visible(tester), contains(created.id));
      expect(_badgeStatus(tester, 'nova.png'), ProjectStatus.notStarted);
    });
  });
}
