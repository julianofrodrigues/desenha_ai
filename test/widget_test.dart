// Testes da Home: novo desenho (Fase 1), abertura da tela de desenho
// (Fase 2) e histórico "Continuar desenhando" (Fase 3).
//
// Em vez de galeria, câmera e disco de verdade, usamos versões FALSAS que
// fazem exatamente o que o teste mandar. Foi para isso que o app recebe os
// serviços por parâmetro.
import 'dart:async';

import 'package:desenha_ai/app.dart';
import 'package:desenha_ai/features/drawing/models/drawing_mode.dart';
import 'package:desenha_ai/features/drawing/models/drawing_settings.dart';
import 'package:desenha_ai/features/drawing/models/overlay_transform.dart';
import 'package:desenha_ai/features/drawing/screens/drawing_screen.dart';
import 'package:desenha_ai/features/image_selection/data/local_image_source.dart';
import 'package:desenha_ai/features/projects/widgets/project_history_tile.dart';
import 'package:desenha_ai/features/projects/widgets/project_search_field.dart';
import 'package:desenha_ai/features/projects/widgets/edit_project_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes.dart';

Widget _app(
  FakeImageSource source, {
  FakeProjectRepository? repository,
  FakeCategoryRepository? categories,
  FakeScreenWakeLock? wakeLock,
}) =>
    DesenhaAiApp(
      imageSource: source,
      projectRepository: repository ?? FakeProjectRepository(),
      categoryRepository: categories ?? FakeCategoryRepository(),
      cameraServiceFactory: FakeCameraService.new,
      screenWakeLock: wakeLock ?? FakeScreenWakeLock(),
    );

FakeImageSource _picks(String name) =>
    FakeImageSource(() async => PickedImage(name: name, bytes: pngBytes));

Future<void> _goBack(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Voltar'));
  await settle(tester);
}

void main() {
  group('novo desenho', () {
    testWidgets('sem histórico, mostra a tela de boas-vindas', (tester) async {
      await tester.pumpWidget(_app(FakeImageSource(() async => null)));
      await tester.pump();

      expect(find.text('Escolha uma imagem de referência'), findsOneWidget);
      expect(find.text('Escolher imagem'), findsOneWidget);
      expect(find.text('Continuar desenhando'), findsNothing);
    });

    testWidgets(
        'escolher imagem CRIA o projeto (cópia local) e abre o desenho',
        (tester) async {
      final completer = Completer<PickedImage?>();
      final repo = FakeProjectRepository();
      await tester.pumpWidget(
        _app(FakeImageSource(() => completer.future), repository: repo),
      );

      await tester.tap(find.text('Escolher imagem'));
      await tester.pump();
      expect(find.text('Abrindo imagem…'), findsOneWidget);

      completer.complete(PickedImage(name: 'gato.png', bytes: pngBytes));
      await settle(tester);

      expect(find.byType(DrawingScreen), findsOneWidget);
      final projects = await repo.listRecent();
      expect(projects.single.originalName, 'gato.png');

      // Ao voltar, o desenho aparece no histórico.
      await _goBack(tester);
      expect(find.text('Continuar desenhando'), findsOneWidget);
      expect(find.text('gato.png'), findsOneWidget);
    });

    testWidgets('cancelar o seletor não cria projeto nem mostra erro',
        (tester) async {
      final repo = FakeProjectRepository();
      await tester.pumpWidget(
        _app(FakeImageSource(() async => null), repository: repo),
      );

      await tester.tap(find.text('Escolher imagem'));
      await settle(tester);

      expect(find.text('Escolha uma imagem de referência'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsNothing);
      expect(await repo.listRecent(), isEmpty);
    });

    testWidgets('falha na leitura mostra erro e permite tentar de novo',
        (tester) async {
      final source = FakeImageSource(
        () async => throw const FormatException('arquivo vazio'),
      );
      await tester.pumpWidget(_app(source));

      await tester.tap(find.text('Escolher imagem'));
      await settle(tester);
      expect(find.text('Tentar novamente'), findsOneWidget);

      source.onPick =
          () async => PickedImage(name: 'flor.jpg', bytes: pngBytes);
      await tester.tap(find.text('Tentar novamente'));
      await settle(tester);
      expect(find.byType(DrawingScreen), findsOneWidget);
    });

    testWidgets('tela fica acesa só enquanto a tela de desenho está aberta',
        (tester) async {
      final wakeLock = FakeScreenWakeLock();
      await tester.pumpWidget(_app(_picks('gato.png'), wakeLock: wakeLock));
      expect(wakeLock.enabled, isFalse); // Home: tela apaga normalmente

      await tester.tap(find.text('Escolher imagem'));
      await settle(tester);
      expect(wakeLock.enabled, isTrue);

      await _goBack(tester);
      expect(wakeLock.enabled, isFalse);
    });
  });

  group('histórico "Continuar desenhando"', () {
    testWidgets('lista do acesso mais recente para o mais antigo, com modo',
        (tester) async {
      final repo = FakeProjectRepository(initial: [
        sampleProject(id: 'a', name: 'antigo.png', updatedAt: DateTime(2025, 1, 1)),
        sampleProject(
          id: 'b',
          name: 'recente.png',
          updatedAt: DateTime(2025, 3, 5, 14, 7),
          settings: const DrawingSettings(mode: DrawingMode.lightTable),
        ),
      ]);
      await tester.pumpWidget(_app(_picks('x.png'), repository: repo));
      await tester.pump();

      final names = tester
          .widgetList<ProjectHistoryTile>(find.byType(ProjectHistoryTile))
          .map((t) => t.project.originalName)
          .toList();
      expect(names, ['recente.png', 'antigo.png']);
      expect(find.text('05/03/2025 14:07 · Mesa de luz'), findsOneWidget);
      expect(find.text('Novo desenho'), findsOneWidget);
    });

    testWidgets('tocar num item reabre o desenho exatamente como estava',
        (tester) async {
      const saved = DrawingSettings(
        transform: OverlayTransform(
          offset: Offset(25, 10),
          scale: 1.5,
          rotation: -0.3,
          flipped: true,
        ),
        opacity: 0.7,
        mode: DrawingMode.lightTable,
      );
      final repo = FakeProjectRepository(
        initial: [sampleProject(name: 'casa.png', settings: saved)],
      );
      await tester.pumpWidget(_app(_picks('x.png'), repository: repo));
      await tester.pump();

      await tester.tap(find.text('casa.png'));
      await settle(tester);

      expect(find.byType(DrawingScreen), findsOneWidget);
      final screen = tester.widget<DrawingScreen>(find.byType(DrawingScreen));
      expect(screen.project.settings, saved);
      expect(tester.widget<Slider>(find.byType(Slider)).value, 0.7);
      final matrix = tester
          .widget<Transform>(
            find.descendant(
              of: find.byType(DrawingScreen),
              matching: find.byType(Transform),
            ).first,
          )
          .transform;
      expect(matrix, saved.transform.toMatrix());
      // Abrir conta como acesso (atualiza a ordem do histórico).
      expect(repo.saves, hasLength(1));
    });

    testWidgets('excluir pede confirmação; "Cancelar" mantém o desenho',
        (tester) async {
      final repo = FakeProjectRepository(
        initial: [sampleProject(name: 'casa.png')],
      );
      await tester.pumpWidget(_app(_picks('x.png'), repository: repo));
      await tester.pump();

      await tester.tap(find.byTooltip('Excluir desenho'));
      await settle(tester);
      expect(find.text('Excluir desenho?'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await settle(tester);

      expect(repo.deleted, isEmpty);
      expect(find.text('casa.png'), findsOneWidget);
    });

    testWidgets('confirmar a exclusão remove o projeto do histórico',
        (tester) async {
      final repo = FakeProjectRepository(initial: [
        sampleProject(id: 'a', name: 'fica.png'),
        sampleProject(id: 'b', name: 'sai.png', updatedAt: DateTime(2025, 2, 1)),
      ]);
      await tester.pumpWidget(_app(_picks('x.png'), repository: repo));
      await tester.pump();

      // O primeiro item é o mais recente ("sai.png").
      await tester.tap(find.byTooltip('Excluir desenho').first);
      await settle(tester);
      await tester.tap(find.text('Excluir'));
      await settle(tester);

      expect(repo.deleted, ['b']);
      expect(find.text('sai.png'), findsNothing);
      expect(find.text('fica.png'), findsOneWidget);
      expect(find.text('Desenho excluído.'), findsOneWidget);
    });

    testWidgets('mostra o nome customizado no lugar do nome do arquivo',
        (tester) async {
      final repo = FakeProjectRepository(initial: [
        sampleProject(name: 'IMG_2025.jpg', customName: 'Gato azul'),
      ]);
      await tester.pumpWidget(_app(_picks('x.png'), repository: repo));
      await tester.pump();

      expect(find.text('Gato azul'), findsOneWidget);
      expect(find.text('IMG_2025.jpg'), findsNothing);
    });

    testWidgets('excluir o último projeto volta à tela de boas-vindas',
        (tester) async {
      final repo = FakeProjectRepository(initial: [sampleProject()]);
      await tester.pumpWidget(_app(_picks('x.png'), repository: repo));
      await tester.pump();

      await tester.tap(find.byTooltip('Excluir desenho'));
      await settle(tester);
      await tester.tap(find.text('Excluir'));
      await settle(tester);

      expect(find.text('Escolha uma imagem de referência'), findsOneWidget);
    });
  });

  group('renomear (Fase 4)', () {
    Future<FakeProjectRepository> pumpWithOne(
      WidgetTester tester, {
      String? customName,
    }) async {
      final repo = FakeProjectRepository(
        initial: [sampleProject(name: 'gato.jpg', customName: customName)],
      );
      await tester.pumpWidget(_app(_picks('x.png'), repository: repo));
      await tester.pump();
      return repo;
    }

    /// Campo de texto DENTRO do diálogo (a Home também tem o da busca).
    Finder dialogField() => find.descendant(
          of: find.byType(EditProjectDialog),
          matching: find.byType(TextField),
        );

    testWidgets('o botão Editar fica à esquerda do botão Remover',
        (tester) async {
      await pumpWithOne(tester);

      final edit = tester.getCenter(find.byTooltip('Editar desenho'));
      final delete = tester.getCenter(find.byTooltip('Excluir desenho'));
      expect(edit.dx, lessThan(delete.dx));
      expect(edit.dy, closeTo(delete.dy, 1)); // mesma linha
    });

    testWidgets('salvar grava o novo nome e atualiza a lista na hora',
        (tester) async {
      final repo = await pumpWithOne(tester);

      await tester.tap(find.byTooltip('Editar desenho'));
      await settle(tester);
      // O campo começa com o nome atual.
      expect(
        tester.widget<TextField>(dialogField()).controller!.text,
        'gato.jpg',
      );

      await tester.enterText(dialogField(), '  Gato azul  ');
      await tester.tap(find.text('Salvar'));
      await settle(tester);

      expect(find.text('Gato azul'), findsOneWidget);
      expect(find.text('gato.jpg'), findsNothing);
      expect(find.text('Desenho renomeado.'), findsOneWidget);
      // Persistiu no repositório, sem alterar o nome original.
      final saved = repo['p1']!;
      expect(saved.customName, 'Gato azul');
      expect(saved.originalName, 'gato.jpg');
    });

    testWidgets('confirmar pelo teclado ("concluído") também salva',
        (tester) async {
      final repo = await pumpWithOne(tester);
      await tester.tap(find.byTooltip('Editar desenho'));
      await settle(tester);

      await tester.enterText(dialogField(), 'Pelo teclado');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);

      expect(repo['p1']!.customName, 'Pelo teclado');
    });

    testWidgets('cancelar mantém o nome anterior', (tester) async {
      final repo = await pumpWithOne(tester, customName: 'Antigo');
      await tester.tap(find.byTooltip('Editar desenho'));
      await settle(tester);

      await tester.enterText(dialogField(), 'Não deve salvar');
      await tester.tap(find.text('Cancelar'));
      await settle(tester);

      expect(find.text('Antigo'), findsOneWidget);
      expect(repo.edits, isEmpty);
    });

    testWidgets('campo vazio ou só espaços volta ao nome original',
        (tester) async {
      final repo = await pumpWithOne(tester, customName: 'Gato azul');
      await tester.tap(find.byTooltip('Editar desenho'));
      await settle(tester);

      await tester.enterText(dialogField(), '    ');
      await tester.tap(find.text('Salvar'));
      await settle(tester);

      expect(find.text('gato.jpg'), findsOneWidget);
      expect(find.text('Nome original restaurado.'), findsOneWidget);
      expect(repo['p1']!.customName, isNull);
    });

    testWidgets('salvar o mesmo nome não grava nada', (tester) async {
      final repo = await pumpWithOne(tester, customName: 'Gato azul');
      await tester.tap(find.byTooltip('Editar desenho'));
      await settle(tester);

      await tester.tap(find.text('Salvar')); // texto inalterado
      await settle(tester);

      expect(repo.edits, isEmpty);
    });

    testWidgets('renomear não muda a ordem do histórico', (tester) async {
      final repo = FakeProjectRepository(initial: [
        sampleProject(id: 'a', name: 'antigo.png', updatedAt: DateTime(2025)),
        sampleProject(id: 'b', name: 'novo.png', updatedAt: DateTime(2026)),
      ]);
      await tester.pumpWidget(_app(_picks('x.png'), repository: repo));
      await tester.pump();

      // Renomeia o item de BAIXO (o mais antigo).
      await tester.tap(find.byTooltip('Editar desenho').last);
      await settle(tester);
      await tester.enterText(dialogField(), 'Renomeado');
      await tester.tap(find.text('Salvar'));
      await settle(tester);

      final names = tester
          .widgetList<ProjectHistoryTile>(find.byType(ProjectHistoryTile))
          .map((t) => t.project.displayName)
          .toList();
      expect(names, ['novo.png', 'Renomeado']);
    });
  });

  group('barra de pesquisa (Fase 4)', () {
    // Pelo widget da barra (e não pelo texto de dica, que some ao digitar).
    Finder searchField() => find.descendant(
          of: find.byType(ProjectSearchField),
          matching: find.byType(TextField),
        );

    List<String> visibleNames(WidgetTester tester) => tester
        .widgetList<ProjectHistoryTile>(find.byType(ProjectHistoryTile))
        .map((t) => t.project.displayName)
        .toList();

    Future<void> pumpHistory(WidgetTester tester) async {
      final repo = FakeProjectRepository(initial: [
        sampleProject(
          id: 'a',
          name: 'IMG_001.jpg',
          customName: 'Pássaro azul',
          updatedAt: DateTime(2025, 3),
        ),
        sampleProject(id: 'b', name: 'gato.png', updatedAt: DateTime(2025, 2)),
        sampleProject(id: 'c', name: '', updatedAt: DateTime(2025, 1)),
      ]);
      await tester.pumpWidget(_app(_picks('x.png'), repository: repo));
      await tester.pump();
    }

    testWidgets('filtra em tempo real, sem acento e sem maiúsculas',
        (tester) async {
      await pumpHistory(tester);
      expect(visibleNames(tester), ['Pássaro azul', 'gato.png', 'Imagem']);

      await tester.enterText(searchField(), 'PASSARO');
      await tester.pump();
      expect(visibleNames(tester), ['Pássaro azul']);

      await tester.enterText(searchField(), 'gat');
      await tester.pump();
      expect(visibleNames(tester), ['gato.png']);
    });

    testWidgets('busca segue a prioridade de nomes', (tester) async {
      await pumpHistory(tester);

      // O nome original de um item renomeado não é usado.
      await tester.enterText(searchField(), 'IMG_001');
      await tester.pump();
      expect(visibleNames(tester), isEmpty);
      expect(
        find.text('Nenhum desenho encontrado para “IMG_001”.'),
        findsOneWidget,
      );

      // Sem nome nenhum, o item é encontrado pelo nome padrão.
      await tester.enterText(searchField(), 'imagem');
      await tester.pump();
      expect(visibleNames(tester), ['Imagem']);
    });

    testWidgets('botão de limpar só aparece com texto e limpa a busca',
        (tester) async {
      await pumpHistory(tester);
      expect(find.byTooltip('Limpar pesquisa'), findsNothing);

      await tester.enterText(searchField(), 'gato');
      await tester.pump();
      expect(find.byTooltip('Limpar pesquisa'), findsOneWidget);
      expect(visibleNames(tester), hasLength(1));

      await tester.tap(find.byTooltip('Limpar pesquisa'));
      await tester.pump();

      expect(find.byTooltip('Limpar pesquisa'), findsNothing);
      expect(visibleNames(tester), hasLength(3));
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('renomear um item faz a busca achar o nome novo',
        (tester) async {
      await pumpHistory(tester);
      await tester.enterText(searchField(), 'cachorro');
      await tester.pump();
      expect(visibleNames(tester), isEmpty);

      await tester.tap(find.byTooltip('Limpar pesquisa'));
      await tester.pump();
      await tester.tap(find.byTooltip('Editar desenho').at(1)); // gato.png
      await settle(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(EditProjectDialog),
          matching: find.byType(TextField),
        ),
        'Cachorro',
      );
      await tester.tap(find.text('Salvar'));
      await settle(tester);

      await tester.enterText(searchField(), 'cachorro');
      await tester.pump();
      expect(visibleNames(tester), ['Cachorro']);
    });

    testWidgets('a Home descarta o controller e o foco sem erros',
        (tester) async {
      await pumpHistory(tester);
      await tester.enterText(searchField(), 'gato');
      await tester.pump();

      // Remover a Home chama o `dispose`. Um controller/FocusNode usado
      // depois de descartado geraria uma exceção aqui.
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  });
}
