// Seleção múltipla: leitura sob demanda (PickedImage) e importação uma por
// vez para o histórico (importPickedImages), sem widgets.
import 'dart:typed_data';

import 'package:desenha_ai/features/image_selection/data/image_importer.dart';
import 'package:desenha_ai/features/image_selection/data/local_image_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

void main() {
  group('PickedImage', () {
    test('lazy: só lê o arquivo quando readBytes é chamado', () async {
      var reads = 0;
      final image = PickedImage.lazy(
        name: 'gato.png',
        read: () async {
          reads++;
          return pngBytes;
        },
      );
      expect(reads, 0); // escolher NÃO carrega a imagem na memória
      expect(await image.readBytes(), pngBytes);
      expect(reads, 1);
    });

    test('arquivo vazio vira FormatException com o nome', () async {
      final image = PickedImage(name: 'vazio.png', bytes: Uint8List(0));
      await expectLater(
        image.readBytes(),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('vazio.png'),
        )),
      );
    });
  });

  group('importPickedImages', () {
    test('cria um projeto por imagem, na ordem escolhida', () async {
      final repo = FakeProjectRepository();
      final result = await importPickedImages(
        [
          PickedImage(name: 'a.png', bytes: pngBytes),
          PickedImage(name: 'b.png', bytes: pngBytes),
          PickedImage(name: 'c.png', bytes: pngBytes),
        ],
        repository: repo,
      );

      expect(result.created.map((p) => p.originalName),
          ['a.png', 'b.png', 'c.png']);
      expect(result.failedNames, isEmpty);
      expect(result.allFailed, isFalse);
      expect(await repo.listRecent(), hasLength(3));
    });

    test('UMA imagem por vez: só lê a próxima depois de salvar a anterior',
        () async {
      final repo = FakeProjectRepository();
      // Para cada leitura, quantas imagens JÁ tinham sido salvas.
      final savedBeforeRead = <int>[];
      PickedImage tracked(String name) => PickedImage.lazy(
            name: name,
            read: () async {
              savedBeforeRead.add(repo.createCalls.length);
              return pngBytes;
            },
          );

      await importPickedImages(
        [tracked('a.png'), tracked('b.png'), tracked('c.png')],
        repository: repo,
      );
      // Se lesse tudo antes (ou em paralelo), seria [0, 0, 0].
      expect(savedBeforeRead, [0, 1, 2]);
    });

    test('uma falha não impede as outras', () async {
      final repo = FakeProjectRepository()
        ..failCreate = (name) => name == 'sem_espaco.png';
      final result = await importPickedImages(
        [
          PickedImage(name: 'a.png', bytes: pngBytes),
          PickedImage(name: 'vazio.png', bytes: Uint8List(0)),
          PickedImage(name: 'sem_espaco.png', bytes: pngBytes),
          PickedImage(name: 'b.png', bytes: pngBytes),
        ],
        repository: repo,
      );

      expect(result.created.map((p) => p.originalName), ['a.png', 'b.png']);
      expect(result.failedNames, ['vazio.png', 'sem_espaco.png']);
      expect(result.total, 4);
      // O arquivo vazio nem chegou ao repositório.
      expect(repo.createCalls, ['a.png', 'sem_espaco.png', 'b.png']);
    });

    test('avisa o progresso ANTES de cada imagem', () async {
      final progress = <(int, int)>[];
      await importPickedImages(
        [
          PickedImage(name: 'a.png', bytes: pngBytes),
          PickedImage(name: 'b.png', bytes: pngBytes),
        ],
        repository: FakeProjectRepository(),
        onProgress: (current, total) => progress.add((current, total)),
      );
      expect(progress, [(1, 2), (2, 2)]);
    });

    test('todas falhando = allFailed', () async {
      final result = await importPickedImages(
        [PickedImage(name: 'vazio.png', bytes: Uint8List(0))],
        repository: FakeProjectRepository(),
      );
      expect(result.allFailed, isTrue);
      expect(result.failedNames, ['vazio.png']);
    });
  });

  group('importSummary', () {
    Future<ImportResult> run(List<String> ok, List<String> bad) =>
        importPickedImages(
          [
            for (final n in ok) PickedImage(name: n, bytes: pngBytes),
            for (final n in bad) PickedImage(name: n, bytes: Uint8List(0)),
          ],
          repository: FakeProjectRepository(),
        );

    test('uma imagem: cita o nome', () async {
      expect(importSummary(await run(['gato.png'], [])),
          '"gato.png" foi adicionada ao histórico.');
    });

    test('várias: mostra a quantidade', () async {
      expect(importSummary(await run(['a.png', 'b.png', 'c.png'], [])),
          '3 imagens adicionadas ao histórico.');
    });

    test('com falhas: diz quantas ficaram de fora', () async {
      expect(importSummary(await run(['a.png', 'b.png'], ['x.png'])),
          '2 imagens adicionadas ao histórico. 1 não pôde ser adicionada.');
      expect(importSummary(await run(['a.png'], ['x.png', 'y.png'])),
          '"a.png" foi adicionada ao histórico. 2 não puderam ser '
          'adicionadas.');
    });
  });
}
