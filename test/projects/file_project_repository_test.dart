// Testes do repositório REAL, gravando em uma pasta temporária do sistema.
// São testes de unidade comuns (`test`), sem widgets: o disco funciona
// normalmente aqui.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:desenha_ai/features/drawing/models/drawing_mode.dart';
import 'package:desenha_ai/features/drawing/models/drawing_settings.dart';
import 'package:desenha_ai/features/drawing/models/overlay_transform.dart';
import 'package:desenha_ai/features/projects/services/file_project_repository.dart';
import 'package:desenha_ai/features/projects/services/project_repository.dart';
import 'package:desenha_ai/features/projects/services/thumbnail_generator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Miniatura falsa: devolve bytes fixos ou falha, conforme o teste.
class _FakeThumbnails implements ThumbnailGenerator {
  _FakeThumbnails({this.fail = false});
  final bool fail;

  @override
  Future<Uint8List> generate(Uint8List imageBytes) async {
    if (fail) throw const FormatException('imagem inválida');
    return Uint8List.fromList([1, 2, 3]);
  }
}

void main() {
  late Directory temp;
  late Directory root;
  late DateTime now;

  FileProjectRepository repository({bool failThumbnails = false}) =>
      FileProjectRepository(
        root: root,
        thumbnails: _FakeThumbnails(fail: failThumbnails),
        clock: () => now = now.add(const Duration(minutes: 1)),
      );

  final image = Uint8List.fromList(List.generate(64, (i) => i));

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('desenha_ai_test');
    root = Directory('${temp.path}${Platform.pathSeparator}projects');
    now = DateTime(2025, 1, 1, 12);
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  group('criação', () {
    test('copia a imagem, gera miniatura e grava o JSON', () async {
      final repo = repository();
      final project = await repo.create(
        originalName: 'Gato.JPG',
        imageBytes: image,
      );

      expect(project.imageFileName, 'image.jpg');
      expect(project.thumbnailFileName, 'thumb.png');
      expect(project.settings, const DrawingSettings());

      // A imagem copiada é idêntica à original.
      expect(await repo.readImage(project), image);
      expect(await repo.thumbnailFile(project)!.exists(), isTrue);

      final json = File(
        '${root.path}/${project.id}/project.json',
      ).readAsStringSync();
      expect(jsonDecode(json), containsPair('schemaVersion', 1));
    });

    test('a cópia continua lá mesmo se o original "sumir"', () async {
      final repo = repository();
      final original = Uint8List.fromList(image);
      final project =
          await repo.create(originalName: 'a.png', imageBytes: original);

      // Simula o arquivo da galeria sendo alterado/apagado: o projeto não
      // depende mais dele.
      original.fillRange(0, original.length, 0);
      expect(await repo.readImage(project), image);
    });

    test('sem miniatura, o projeto é criado mesmo assim', () async {
      final repo = repository(failThumbnails: true);
      final project =
          await repo.create(originalName: 'x.heic', imageBytes: image);
      expect(project.thumbnailFileName, isNull);
      expect(repo.thumbnailFile(project), isNull);
      expect(await repo.listRecent(), hasLength(1));
    });

    test('extensão estranha no nome vira "img"', () async {
      final project = await repository()
          .create(originalName: 'foto.../../x', imageBytes: image);
      expect(project.imageFileName, 'image.img');
    });
  });

  group('retomada', () {
    test('save grava os ajustes e eles voltam idênticos ao listar', () async {
      final repo = repository();
      final created =
          await repo.create(originalName: 'a.png', imageBytes: image);

      const settings = DrawingSettings(
        transform: OverlayTransform(
          offset: Offset(12.5, -40.25),
          scale: 2.75,
          rotation: 1.2345,
          flipped: true,
        ),
        opacity: 0.65,
        mode: DrawingMode.lightTable,
        lightTableColor: LightTableColor.black,
      );
      final saved = await repo.save(created.copyWith(settings: settings));
      expect(saved.updatedAt.isAfter(created.updatedAt), isTrue);

      // Um repositório NOVO (como se o app tivesse sido reaberto) lê do disco.
      final reloaded = (await repository().listRecent()).single;
      expect(reloaded.settings, settings);
      expect(reloaded.id, created.id);
      expect(reloaded.updatedAt, saved.updatedAt);
    });

    test('lista do acesso mais recente para o mais antigo', () async {
      final repo = repository();
      final a = await repo.create(originalName: 'a.png', imageBytes: image);
      final b = await repo.create(originalName: 'b.png', imageBytes: image);
      expect((await repo.listRecent()).map((p) => p.id), [b.id, a.id]);

      await repo.save(a); // abrir "a" de novo
      expect((await repo.listRecent()).map((p) => p.id), [a.id, b.id]);
    });

    test('um project.json corrompido não esconde os outros', () async {
      final repo = repository();
      final ok = await repo.create(originalName: 'ok.png', imageBytes: image);
      final bad = await repo.create(originalName: 'x.png', imageBytes: image);
      File('${root.path}/${bad.id}/project.json').writeAsStringSync('{lixo');

      final list = await repo.listRecent();
      expect(list.map((p) => p.id), [ok.id]);
    });

    test('gravações simultâneas ficam em fila (a última vence)', () async {
      final repo = repository();
      final p = await repo.create(originalName: 'a.png', imageBytes: image);

      await Future.wait([
        repo.save(p.copyWith(settings: const DrawingSettings(opacity: 0.2))),
        repo.save(p.copyWith(settings: const DrawingSettings(opacity: 0.9))),
      ]);
      expect((await repo.listRecent()).single.settings.opacity, 0.9);
    });

    test('histórico vazio quando a pasta ainda não existe', () async {
      expect(await repository().listRecent(), isEmpty);
    });
  });

  group('exclusão', () {
    test('remove registro, imagem e miniatura (a pasta inteira)', () async {
      final repo = repository();
      final keep = await repo.create(originalName: 'a.png', imageBytes: image);
      final gone = await repo.create(originalName: 'b.png', imageBytes: image);
      final goneDir = Directory('${root.path}/${gone.id}');
      expect(await goneDir.exists(), isTrue);

      await repo.delete(gone);

      expect(await goneDir.exists(), isFalse);
      expect((await repo.listRecent()).map((p) => p.id), [keep.id]);
      await expectLater(
        repo.readImage(gone),
        throwsA(isA<ProjectNotFoundException>()),
      );
    });

    test('salvar um projeto excluído não o recria', () async {
      final repo = repository();
      final p = await repo.create(originalName: 'a.png', imageBytes: image);
      await repo.delete(p);

      await expectLater(
        repo.save(p),
        throwsA(isA<ProjectNotFoundException>()),
      );
      expect(await Directory('${root.path}/${p.id}').exists(), isFalse);
    });
  });
}
