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
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes.dart';

Widget _app(
  FakeImageSource source, {
  FakeProjectRepository? repository,
  FakeScreenWakeLock? wakeLock,
}) =>
    DesenhaAiApp(
      imageSource: source,
      projectRepository: repository ?? FakeProjectRepository(),
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
}
