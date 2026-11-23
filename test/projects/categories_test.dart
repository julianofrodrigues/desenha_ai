// Fase 5 (Etapa 5A): modelo e persistência de categorias, e limpeza do
// vínculo nos projetos. Usa os repositórios REAIS numa pasta temporária.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:desenha_ai/features/projects/models/drawing_project.dart';
import 'package:desenha_ai/features/projects/models/project_category.dart';
import 'package:desenha_ai/features/projects/services/file_category_repository.dart';
import 'package:desenha_ai/features/projects/services/file_project_repository.dart';
import 'package:desenha_ai/features/projects/services/thumbnail_generator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

class _NoThumbnails implements ThumbnailGenerator {
  @override
  Future<Uint8List> generate(Uint8List imageBytes) async =>
      Uint8List.fromList([1]);
}

void main() {
  group('validateCategoryName', () {
    final existing = [sampleCategory(name: 'Animais')];

    test('aceita um nome novo', () {
      expect(validateCategoryName('Retratos', existing), isNull);
    });

    test('recusa vazio ou só espaços', () {
      expect(validateCategoryName('', existing), CategoryNameError.empty);
      expect(validateCategoryName('   ', existing), CategoryNameError.empty);
    });

    test('recusa duplicado ignorando maiúsculas, acentos e espaços', () {
      expect(
        validateCategoryName('  ANIMAIS ', existing),
        CategoryNameError.duplicate,
      );
      expect(
        validateCategoryName('Ânimais', existing),
        CategoryNameError.duplicate,
      );
    });

    test('recusa nome longo demais', () {
      expect(
        validateCategoryName('x' * (ProjectCategory.maxNameLength + 1), []),
        CategoryNameError.tooLong,
      );
    });
  });

  group('JSON', () {
    test('categoria: ida e volta sem perda', () {
      final c = sampleCategory();
      final json = jsonDecode(jsonEncode(c.toJson())) as Map<String, Object?>;
      expect(ProjectCategory.fromJson(json), c);
    });

    test('cor inválida vira a primeira da paleta; sem nome é recusada', () {
      expect(
        ProjectCategory.fromJson({'id': 'c1', 'name': 'A', 'color': 'azul'})
            .colorValue,
        categoryPalette.first.value,
      );
      expect(
        () => ProjectCategory.fromJson({'id': 'c1', 'name': '  '}),
        throwsFormatException,
      );
    });

    test('projeto: categoryId vai e volta; ausente ou inválido vira null',
        () {
      final p = sampleProject(categoryId: 'c1');
      final json = jsonDecode(jsonEncode(p.toJson())) as Map<String, Object?>;
      expect(DrawingProject.fromJson(json).categoryId, 'c1');

      expect(
        DrawingProject.fromJson({...json}..remove('categoryId')).categoryId,
        isNull,
      );
      expect(
        DrawingProject.fromJson({...json, 'categoryId': '../x'}).categoryId,
        isNull,
      );
    });

    test('categoryIn: categoria inexistente conta como "sem categoria"', () {
      final animais = sampleCategory(id: 'c1');
      final byId = {animais.id: animais};
      expect(sampleProject(categoryId: 'c1').categoryIn(byId), animais);
      expect(sampleProject(categoryId: 'apagada').categoryIn(byId), isNull);
      expect(sampleProject().categoryIn(byId), isNull);
    });
  });

  group('FileCategoryRepository', () {
    late Directory temp;
    late File file;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('desenha_ai_cat');
      file = File('${temp.path}${Platform.pathSeparator}categories.json');
    });

    tearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    test('sem arquivo, não há categorias', () async {
      expect(await FileCategoryRepository(file: file).listAll(), isEmpty);
    });

    test('cria, persiste no disco e lista em ordem alfabética', () async {
      final repo = FileCategoryRepository(file: file);
      await repo.create(name: '  Retratos ', colorValue: 0xFF1E88E5);
      await repo.create(name: 'Animais', colorValue: 0xFF43A047);

      // Repositório NOVO = app reaberto.
      final list = await FileCategoryRepository(file: file).listAll();
      expect(list.map((c) => c.name), ['Animais', 'Retratos']);
      expect(list.last.colorValue, 0xFF1E88E5);
    });

    test('recusa nome vazio ou duplicado sem gravar nada', () async {
      final repo = FileCategoryRepository(file: file);
      await repo.create(name: 'Animais', colorValue: 0xFF43A047);

      await expectLater(
        repo.create(name: '   ', colorValue: 0xFF43A047),
        throwsA(isA<CategoryValidationException>()),
      );
      await expectLater(
        repo.create(name: 'animais', colorValue: 0xFF43A047),
        throwsA(
          isA<CategoryValidationException>().having(
            (e) => e.error,
            'error',
            CategoryNameError.duplicate,
          ),
        ),
      );
      expect(await repo.listAll(), hasLength(1));
    });

    test('criações simultâneas não apagam uma à outra (fila)', () async {
      final repo = FileCategoryRepository(file: file);
      await Future.wait([
        repo.create(name: 'A', colorValue: 0xFF43A047),
        repo.create(name: 'B', colorValue: 0xFF43A047),
        repo.create(name: 'C', colorValue: 0xFF43A047),
      ]);
      expect((await repo.listAll()).map((c) => c.name), ['A', 'B', 'C']);
    });

    test('remove só a categoria escolhida', () async {
      final repo = FileCategoryRepository(file: file);
      final a = await repo.create(name: 'A', colorValue: 0xFF43A047);
      await repo.create(name: 'B', colorValue: 0xFF43A047);

      await repo.delete(a);
      expect((await repo.listAll()).map((c) => c.name), ['B']);
      await repo.delete(a); // de novo: não é erro
    });

    test('arquivo corrompido = sem categorias (o app não quebra)', () async {
      file.writeAsStringSync('{lixo');
      expect(await FileCategoryRepository(file: file).listAll(), isEmpty);
    });
  });

  group('remover categoria limpa o vínculo dos projetos', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('desenha_ai_link');
    });

    tearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    test('só os projetos daquela categoria ficam sem categoria', () async {
      final projects = FileProjectRepository(
        root: Directory('${temp.path}${Platform.pathSeparator}projects'),
        thumbnails: _NoThumbnails(),
      );
      final categories = FileCategoryRepository(
        file: File('${temp.path}${Platform.pathSeparator}categories.json'),
      );
      final animais =
          await categories.create(name: 'Animais', colorValue: 0xFF43A047);
      final retratos =
          await categories.create(name: 'Retratos', colorValue: 0xFF1E88E5);

      final image = Uint8List.fromList([1, 2, 3]);
      Future<DrawingProject> make(String name, String categoryId) async {
        final p = await projects.create(originalName: name, imageBytes: image);
        return projects.updateDetails(
          p,
          customName: null,
          categoryId: categoryId,
        );
      }

      final gato = await make('gato.png', animais.id);
      final cao = await make('cao.png', animais.id);
      final rosto = await make('rosto.png', retratos.id);

      // O mesmo fluxo da tela de categorias: remove, depois limpa.
      await categories.delete(animais);
      final cleared = await projects.clearCategory(animais.id);
      expect(cleared, 2);

      final byId = {for (final p in await projects.listRecent()) p.id: p};
      expect(byId[gato.id]!.categoryId, isNull);
      expect(byId[cao.id]!.categoryId, isNull);
      expect(byId[rosto.id]!.categoryId, retratos.id);
      // O resto do projeto continua igual.
      expect(byId[gato.id]!.originalName, 'gato.png');
    });

    test('editar categoria não muda o último acesso nem o nome', () async {
      final projects = FileProjectRepository(
        root: Directory('${temp.path}${Platform.pathSeparator}projects'),
        thumbnails: _NoThumbnails(),
      );
      final p = await projects.create(
        originalName: 'gato.png',
        imageBytes: Uint8List.fromList([1]),
      );
      final renamed =
          await projects.updateDetails(p, customName: 'Gato', categoryId: null);

      final withCategory = await projects.updateDetails(
        renamed,
        customName: renamed.customName,
        categoryId: 'c1',
      );
      expect(withCategory.categoryId, 'c1');
      expect(withCategory.customName, 'Gato');
      expect(withCategory.updatedAt, p.updatedAt);
    });
  });
}
