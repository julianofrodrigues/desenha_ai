// Testes da tela de desenho com uma câmera FALSA: não há hardware nem
// diálogo de permissão, então controlamos exatamente o que a "câmera" faz.
import 'package:desenha_ai/features/drawing/screens/drawing_screen.dart';
import 'package:desenha_ai/features/drawing/services/camera_service.dart';
import 'package:desenha_ai/features/drawing/widgets/lock_button.dart';
import 'package:desenha_ai/features/drawing/widgets/reference_overlay.dart';
import 'package:desenha_ai/features/drawing/models/drawing_mode.dart';
import 'package:desenha_ai/features/drawing/models/drawing_settings.dart';
import 'package:desenha_ai/features/drawing/models/overlay_transform.dart';
import 'package:desenha_ai/features/projects/models/drawing_project.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../fakes.dart';

Future<FakeCameraService> _pumpScreen(
  WidgetTester tester, {
  CameraStatus Function()? onStart,
  bool torchSupported = false,
  FakeScreenWakeLock? wakeLock,
  FakeProjectRepository? repository,
  DrawingProject? project,
}) async {
  final camera = FakeCameraService(
    onStart: onStart,
    torchSupported: torchSupported,
  );
  final theProject = project ?? sampleProject();
  final repo =
      repository ?? FakeProjectRepository(initial: [theProject]);
  await tester.pumpWidget(
    MaterialApp(
      home: DrawingScreen(
        project: theProject,
        imageBytes: pngBytes,
        projectRepository: repo,
        cameraServiceFactory: () => camera,
        screenWakeLock: wakeLock ?? FakeScreenWakeLock(),
        themeController: fakeThemeController(),
      ),
    ),
  );
  await tester.pump();
  return camera;
}

/// Matriz aplicada à imagem de referência.
Matrix4 _overlayMatrix(WidgetTester tester) => tester
    .widget<Transform>(
      find.descendant(
        of: find.byType(ReferenceOverlay),
        matching: find.byType(Transform),
      ),
    )
    .transform;

void main() {
  testWidgets('liga a câmera ao abrir e a descarta ao fechar', (tester) async {
    final camera = await _pumpScreen(tester);
    expect(camera.startCalls, 1);

    await tester.pumpWidget(const SizedBox());
    expect(camera.disposed, isTrue);
  });

  group('retomada e salvamento automático (Fase 3)', () {
    const saved = DrawingSettings(
      transform: OverlayTransform(
        offset: Offset(40, -30),
        scale: 2,
        rotation: 0.5,
        flipped: true,
      ),
      opacity: 0.8,
      mode: DrawingMode.lightTable,
      lightTableColor: LightTableColor.black,
    );

    testWidgets('restaura exatamente os ajustes salvos', (tester) async {
      final camera = await _pumpScreen(
        tester,
        project: sampleProject(settings: saved),
      );

      expect(_overlayMatrix(tester), saved.transform.toMatrix());
      expect(tester.widget<Slider>(find.byType(Slider)).value, 0.8);
      expect(find.text('80%'), findsOneWidget);
      // Mesa de luz preta: o botão oferece voltar ao branco.
      expect(find.byTooltip('Fundo branco'), findsOneWidget);
      // Reabrir na Mesa de Luz não liga a câmera à toa.
      expect(camera.startCalls, 0);
    });

    testWidgets('várias mudanças seguidas viram UMA gravação (debounce)',
        (tester) async {
      final project = sampleProject();
      final repo = FakeProjectRepository(initial: [project]);
      await _pumpScreen(tester, repository: repo, project: project);

      // Três mudanças em sequência rápida.
      await tester.tap(find.byTooltip('Espelhar imagem'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.dragFrom(const Offset(100, 250), const Offset(80, 40));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Mesa de luz'));
      await tester.pump(const Duration(milliseconds: 200));

      // Ainda dentro do intervalo de debounce: nada gravado.
      expect(repo.saves, isEmpty);

      await tester.pump(DrawingScreen.autosaveDelay);
      expect(repo.saves, hasLength(1));

      final settings = repo[project.id]!.settings;
      expect(settings.transform.flipped, isTrue);
      expect(settings.transform.offset.dx, greaterThan(0));
      expect(settings.mode, DrawingMode.lightTable);
    });

    testWidgets('sair da tela grava a mudança que ainda estava pendente',
        (tester) async {
      final project = sampleProject();
      final repo = FakeProjectRepository(initial: [project]);
      await _pumpScreen(tester, repository: repo, project: project);

      await tester.tap(find.byTooltip('Espelhar imagem'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(repo.saves, isEmpty);

      await tester.pumpWidget(const SizedBox()); // dispose da tela
      await tester.pump();
      expect(repo.saves, hasLength(1));
      expect(repo[project.id]!.settings.transform.flipped, isTrue);
    });

    testWidgets('minimizar o app grava na hora', (tester) async {
      final project = sampleProject();
      final repo = FakeProjectRepository(initial: [project]);
      await _pumpScreen(tester, repository: repo, project: project);

      await tester.tap(find.byTooltip('Resetar posição'));
      await tester.tap(find.byTooltip('Espelhar imagem'));
      await tester.pump(const Duration(milliseconds: 100));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(repo.saves, hasLength(1));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
    });

    testWidgets('sem mudanças, nada é gravado', (tester) async {
      final project = sampleProject();
      final repo = FakeProjectRepository(initial: [project]);
      await _pumpScreen(tester, repository: repo, project: project);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox());
      expect(repo.saves, isEmpty);
    });
  });

  group('tela sempre acesa (wakelock)', () {
    testWidgets('liga ao abrir e desliga no dispose', (tester) async {
      final wakeLock = FakeScreenWakeLock();
      await _pumpScreen(tester, wakeLock: wakeLock);
      expect(wakeLock.enabled, isTrue);

      await tester.pumpWidget(const SizedBox());
      expect(wakeLock.enabled, isFalse);
    });

    testWidgets('continua ligado na Mesa de Luz', (tester) async {
      final wakeLock = FakeScreenWakeLock();
      await _pumpScreen(tester, wakeLock: wakeLock);

      await tester.tap(find.text('Mesa de luz'));
      await tester.pump();
      expect(wakeLock.enabled, isTrue);
    });

    testWidgets('desliga ao minimizar e religa ao voltar', (tester) async {
      final wakeLock = FakeScreenWakeLock();
      await _pumpScreen(tester, wakeLock: wakeLock);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(wakeLock.enabled, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(wakeLock.enabled, isTrue);
    });
  });

  group('permissão negada', () {
    testWidgets('oferece a Mesa de Luz e troca de modo sem travar',
        (tester) async {
      final camera = await _pumpScreen(
        tester,
        onStart: () => const CameraPermissionDenied(),
      );

      expect(find.text('Sem acesso à câmera'), findsOneWidget);

      await tester.tap(find.text('Usar Mesa de Luz'));
      await tester.pump();

      expect(find.text('Sem acesso à câmera'), findsNothing);
      expect(camera.stopCalls, 1); // câmera desligada de verdade
      // Controle exclusivo da Mesa de Luz apareceu.
      expect(find.byTooltip('Fundo preto'), findsOneWidget);
    });

    testWidgets('"Tentar novamente" pede a câmera de novo', (tester) async {
      final camera = await _pumpScreen(
        tester,
        onStart: () => const CameraPermissionDenied(),
      );
      await tester.tap(find.text('Tentar novamente'));
      await tester.pump();
      expect(camera.startCalls, 2);
    });
  });

  group('trava', () {
    testWidgets('travar esconde os controles e bloqueia gestos',
        (tester) async {
      await _pumpScreen(tester);
      expect(find.byType(Slider), findsOneWidget);

      await tester.tap(find.byType(LockButton));
      await tester.pump();

      expect(find.byType(Slider), findsNothing);
      expect(find.byTooltip('Voltar'), findsNothing);

      final before = _overlayMatrix(tester);
      await tester.dragFrom(const Offset(100, 250), const Offset(120, 60));
      await tester.pump();
      expect(_overlayMatrix(tester), before);
    });

    testWidgets('toque simples NÃO destrava; toque duplo destrava',
        (tester) async {
      await _pumpScreen(tester);
      await tester.tap(find.byType(LockButton));
      await tester.pump();

      await tester.tap(find.byType(LockButton));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(Slider), findsNothing);

      await tester.tap(find.byType(LockButton));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(find.byType(LockButton));
      await tester.pump();
      expect(find.byType(Slider), findsOneWidget);

      // Deixa expirar o temporizador interno do reconhecedor de toque duplo.
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('segurar por 1,5 s destrava; soltar antes não',
        (tester) async {
      await _pumpScreen(tester);
      await tester.tap(find.byType(LockButton));
      await tester.pump();

      final center = tester.getCenter(find.byType(LockButton));

      // Segura só 0,7 s.
      var gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.up();
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(Slider), findsNothing);

      // Segura por 2 s (com folga sobre os 1,5 s exigidos).
      gesture = await tester.startGesture(center);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await gesture.up();
      await tester.pump();
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('com a tela travada, o "voltar" do Android não sai',
        (tester) async {
      await _pumpScreen(tester);
      await tester.tap(find.byType(LockButton));
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(find.byType(DrawingScreen), findsOneWidget);
      expect(
        find.text('Tela travada. Destrave no cadeado para sair.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('arrastar move a imagem e "Resetar posição" volta ao centro',
      (tester) async {
    await _pumpScreen(tester);

    await tester.dragFrom(const Offset(100, 250), const Offset(120, 60));
    await tester.pump();
    final moved = _overlayMatrix(tester).getTranslation();
    expect(moved.x, greaterThan(50));
    expect(moved.y, greaterThan(20));

    await tester.tap(find.byTooltip('Resetar posição'));
    await tester.pump();
    final reset = _overlayMatrix(tester).getTranslation();
    expect(reset.x, 0);
    expect(reset.y, 0);
  });

  testWidgets('espelhar inverte o eixo X da imagem', (tester) async {
    await _pumpScreen(tester);
    expect(_overlayMatrix(tester).entry(0, 0), 1);

    await tester.tap(find.byTooltip('Espelhar imagem'));
    await tester.pump();
    expect(_overlayMatrix(tester).entry(0, 0), -1);
  });

  testWidgets('slider de opacidade começa em 50% e vai de 10% a 100%',
      (tester) async {
    await _pumpScreen(tester);
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 0.5);
    expect(slider.min, 0.1);
    expect(slider.max, 1.0);
    expect(find.text('50%'), findsOneWidget);
  });

  group('lanterna', () {
    testWidgets('só aparece com a câmera pronta', (tester) async {
      await _pumpScreen(tester); // câmera falsa fica "desligada"
      expect(find.byTooltip('Ligar lanterna'), findsNothing);
    });

    testWidgets('avisa quando o aparelho não tem lanterna', (tester) async {
      await _pumpScreen(tester, onStart: fakeReadyStatus);
      await tester.tap(find.byTooltip('Ligar lanterna'));
      await tester.pump();
      expect(find.text('Este aparelho não tem lanterna.'), findsOneWidget);
    });

    testWidgets('liga quando suportada', (tester) async {
      await _pumpScreen(
        tester,
        onStart: fakeReadyStatus,
        torchSupported: true,
      );
      await tester.tap(find.byTooltip('Ligar lanterna'));
      await tester.pump();
      expect(find.byTooltip('Desligar lanterna'), findsOneWidget);
    });
  });

  testWidgets('desliga a câmera em segundo plano e religa ao voltar',
      (tester) async {
    final camera = await _pumpScreen(tester, onStart: fakeReadyStatus);
    expect(camera.startCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(camera.stopCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(camera.startCalls, 2);
  });
}
