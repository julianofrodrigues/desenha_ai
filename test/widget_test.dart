// Testes da Home (Fase 1) e da navegação para a tela de desenho (Fase 2).
//
// Em vez de abrir a galeria de verdade (impossível num teste automatizado),
// usamos fontes FALSAS que devolvem o que o teste mandar. Foi para isso que
// o app recebe os serviços por parâmetro.
import 'dart:async';

import 'package:desenha_ai/app.dart';
import 'package:desenha_ai/features/drawing/screens/drawing_screen.dart';
import 'package:desenha_ai/features/image_selection/data/local_image_source.dart';
import 'package:desenha_ai/features/image_selection/presentation/home_page.dart';
import 'package:desenha_ai/features/image_selection/presentation/widgets/image_preview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes.dart';

Widget _app(FakeImageSource source, {FakeScreenWakeLock? wakeLock}) =>
    DesenhaAiApp(
      imageSource: source,
      cameraServiceFactory: FakeCameraService.new,
      screenWakeLock: wakeLock ?? FakeScreenWakeLock(),
    );

Future<void> _goBack(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Voltar'));
  await settle(tester);
}

void main() {
  testWidgets('mostra o estado vazio com o botão de escolher imagem',
      (tester) async {
    await tester.pumpWidget(_app(FakeImageSource(() async => null)));

    expect(find.text('Escolha uma imagem de referência'), findsOneWidget);
    expect(find.text('Escolher imagem'), findsOneWidget);
  });

  testWidgets('mostra loading e, ao escolher, abre a tela de desenho',
      (tester) async {
    final completer = Completer<PickedImage?>();
    await tester.pumpWidget(_app(FakeImageSource(() => completer.future)));

    await tester.tap(find.text('Escolher imagem'));
    await tester.pump();
    expect(find.text('Abrindo imagem…'), findsOneWidget);

    completer.complete(PickedImage(name: 'gato.png', bytes: pngBytes));
    await settle(tester);

    expect(find.byType(DrawingScreen), findsOneWidget);

    // Ao voltar, a prévia continua na Home.
    await _goBack(tester);
    expect(find.text('gato.png'), findsOneWidget);
    expect(find.byType(ImagePreview), findsOneWidget);
  });

  testWidgets('tela fica acesa só enquanto a tela de desenho está aberta',
      (tester) async {
    final wakeLock = FakeScreenWakeLock();
    await tester.pumpWidget(
      _app(
        FakeImageSource(
          () async => PickedImage(name: 'gato.png', bytes: pngBytes),
        ),
        wakeLock: wakeLock,
      ),
    );
    expect(wakeLock.enabled, isFalse); // Home: tela apaga normalmente

    await tester.tap(find.text('Escolher imagem'));
    await settle(tester);
    expect(wakeLock.enabled, isTrue);

    await _goBack(tester);
    expect(wakeLock.enabled, isFalse);
  });

  testWidgets('botão "Desenhar" reabre a tela de desenho', (tester) async {
    await tester.pumpWidget(
      _app(FakeImageSource(
        () async => PickedImage(name: 'gato.png', bytes: pngBytes),
      )),
    );
    await tester.tap(find.text('Escolher imagem'));
    await settle(tester);
    await _goBack(tester);

    await tester.tap(find.text('Desenhar'));
    await settle(tester);
    expect(find.byType(DrawingScreen), findsOneWidget);
  });

  testWidgets('cancelar o seletor volta ao estado anterior sem erro',
      (tester) async {
    await tester.pumpWidget(_app(FakeImageSource(() async => null)));

    await tester.tap(find.text('Escolher imagem'));
    await settle(tester);

    expect(find.text('Escolha uma imagem de referência'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
    expect(find.byType(DrawingScreen), findsNothing);
  });

  testWidgets('cancelar "Trocar imagem" mantém a imagem e não abre o desenho',
      (tester) async {
    final source = FakeImageSource(
      () async => PickedImage(name: 'gato.png', bytes: pngBytes),
    );
    await tester.pumpWidget(_app(source));
    await tester.tap(find.text('Escolher imagem'));
    await settle(tester);
    await _goBack(tester);

    source.onPick = () async => null;
    await tester.tap(find.text('Trocar imagem'));
    await settle(tester);

    expect(find.text('gato.png'), findsOneWidget);
    expect(find.byType(DrawingScreen), findsNothing);
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

    source.onPick = () async => PickedImage(name: 'flor.jpg', bytes: pngBytes);
    await tester.tap(find.text('Tentar novamente'));
    await settle(tester);
    expect(find.byType(DrawingScreen), findsOneWidget);
  });

  test('formatBytes usa unidades legíveis e vírgula decimal', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(1536), '1,5 KB');
    expect(formatBytes(5 * 1024 * 1024), '5,0 MB');
  });
}
