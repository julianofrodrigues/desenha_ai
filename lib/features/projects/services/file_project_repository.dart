import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../drawing/models/drawing_settings.dart';
import '../models/drawing_project.dart';
import '../models/project_status.dart';
import 'project_repository.dart';
import 'thumbnail_generator.dart';

/// Histórico de projetos em arquivos, no armazenamento interno do app.
///
/// Estrutura em disco (uma pasta por projeto):
///
/// ```
/// <root>/                  ← ex.: /data/user/0/<pacote>/app_flutter/projects
///   lq3k9x2a7f/
///     project.json         ← metadados + ajustes (DrawingProject.toJson)
///     image.jpg            ← CÓPIA da imagem escolhida
///     thumb.png            ← miniatura de até 256 px
///   lq3kb1c0d2/
///     ...
/// ```
///
/// Por que uma pasta por projeto, e não um banco de dados?
/// - Excluir = apagar uma pasta. Não sobra imagem "órfã" ocupando espaço.
/// - Cada projeto é independente: um `project.json` corrompido afeta só ele.
/// - Para dezenas de projetos, ler alguns JSONs pequenos é instantâneo.
///   Um banco (sqflite/drift) só compensaria com milhares de itens ou buscas.
class FileProjectRepository implements ProjectRepository {
  FileProjectRepository({
    required this.root,
    required this.thumbnails,
    DateTime Function()? clock,
    Random? random,
  })  : _clock = clock ?? DateTime.now,
        _random = random ?? Random();

  /// Pasta raiz do histórico. No app, fica dentro de
  /// `getApplicationDocumentsDirectory()` (ver `main.dart`); nos testes, numa
  /// pasta temporária.
  final Directory root;

  /// Gera as miniaturas da lista (real no app, falsa nos testes).
  final ThumbnailGenerator thumbnails;
  final DateTime Function() _clock;
  final Random _random;

  static const _projectFile = 'project.json';
  static const _thumbnailFile = 'thumb.png';

  /// Fila de escritas. Toda operação que GRAVA passa por aqui, uma de cada
  /// vez. Sem isso, um salvamento automático e uma exclusão (ou dois
  /// salvamentos) poderiam se intercalar e deixar arquivos inconsistentes.
  Future<void> _writes = Future.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _writes.then((_) => action());
    // A fila continua mesmo se esta operação falhar.
    _writes = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  // -------------------------------------------------------------------------
  // Operações públicas
  // -------------------------------------------------------------------------

  @override
  Future<DrawingProject> create({
    required String originalName,
    required Uint8List imageBytes,
  }) {
    return _serialized(() async {
      final now = _clock();
      final id = _newId(now);
      final dir = _projectDir(id);
      await dir.create(recursive: true);

      try {
        final imageFileName = 'image.${_safeExtension(originalName)}';
        // `flush: true` força a gravação física antes de continuar: se o app
        // for morto logo depois, a imagem já está no disco.
        await _file(dir, imageFileName).writeAsBytes(imageBytes, flush: true);

        String? thumbnailFileName;
        try {
          final thumb = await thumbnails.generate(imageBytes);
          await _file(dir, _thumbnailFile).writeAsBytes(thumb, flush: true);
          thumbnailFileName = _thumbnailFile;
        } catch (error) {
          // Sem miniatura o projeto continua utilizável (a lista mostra um
          // ícone no lugar). Não vale perder o desenho por isso.
          debugPrint('Miniatura não gerada para $id: $error');
        }

        final project = DrawingProject(
          id: id,
          originalName: originalName,
          imageFileName: imageFileName,
          thumbnailFileName: thumbnailFileName,
          createdAt: now,
          updatedAt: now,
          settings: const DrawingSettings(),
        );
        await _writeProject(dir, project);
        return project;
      } catch (_) {
        // Falhou no meio (ex.: armazenamento cheio): apaga o que foi
        // gravado, para não deixar um projeto pela metade no histórico.
        await _deleteQuietly(dir);
        rethrow;
      }
    });
  }

  @override
  Future<List<DrawingProject>> listRecent() async {
    if (!await root.exists()) return const [];

    final projects = <DrawingProject>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final file = _file(entity, _projectFile);
      if (!await file.exists()) continue;
      try {
        final json = jsonDecode(await file.readAsString());
        projects.add(DrawingProject.fromJson(json as Map<String, Object?>));
      } catch (error) {
        // Um projeto ilegível não pode esconder os outros.
        debugPrint('Projeto ignorado (${entity.path}): $error');
      }
    }

    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return projects;
  }

  @override
  Future<Uint8List> readImage(DrawingProject project) async {
    final file = _file(_projectDir(project.id), project.imageFileName);
    if (!await file.exists()) throw ProjectNotFoundException(project.id);
    return file.readAsBytes();
  }

  @override
  File? thumbnailFile(DrawingProject project) {
    final name = project.thumbnailFileName;
    if (name == null) return null;
    return _file(_projectDir(project.id), name);
  }

  @override
  Future<DrawingProject> save(DrawingProject project) {
    return _serialized(() async {
      final dir = _projectDir(project.id);
      // Se o projeto foi excluído, NÃO recriamos a pasta: ficaria um
      // registro sem imagem no histórico.
      if (!await _file(dir, _projectFile).exists()) {
        throw ProjectNotFoundException(project.id);
      }
      final updated = project.copyWith(updatedAt: _clock());
      await _writeProject(dir, updated);
      return updated;
    });
  }

  @override
  Future<DrawingProject> updateDetails(
    DrawingProject project, {
    required String? customName,
    required String? categoryId,
  }) {
    return _serialized(() async {
      final dir = _projectDir(project.id);
      final file = _file(dir, _projectFile);
      if (!await file.exists()) throw ProjectNotFoundException(project.id);

      // Partimos do que está no DISCO, e não do objeto recebido. A lista da
      // Home pode estar um pouco desatualizada (ex.: o salvamento automático
      // da tela de desenho terminou depois de a lista ser lida). Se
      // gravássemos o objeto da lista, os ajustes mais novos seriam perdidos.
      final current = await _readProject(file);

      final updated =
          current.rename(customName).withCategory(categoryId);
      // Nada mudou: evita uma gravação inútil na memória flash.
      if (updated != current) await _writeProject(dir, updated);
      return updated;
    });
  }

  @override
  Future<DrawingProject> updateStatus(
    DrawingProject project,
    ProjectStatus status,
  ) {
    return _serialized(() async {
      final dir = _projectDir(project.id);
      final file = _file(dir, _projectFile);
      if (!await file.exists()) throw ProjectNotFoundException(project.id);

      // Do DISCO, pelo mesmo motivo do `updateDetails`: não perder ajustes
      // gravados depois de a lista da Home ser lida.
      final current = await _readProject(file);
      final updated = current.withStatus(status);
      if (updated != current) await _writeProject(dir, updated);
      return updated;
    });
  }

  @override
  Future<int> clearCategory(String categoryId) {
    return _serialized(() async {
      if (!await root.exists()) return 0;
      var changed = 0;
      await for (final entity in root.list(followLinks: false)) {
        if (entity is! Directory) continue;
        final file = _file(entity, _projectFile);
        if (!await file.exists()) continue;
        try {
          final project = await _readProject(file);
          if (project.categoryId != categoryId) continue;
          await _writeProject(entity, project.withCategory(null));
          changed++;
        } catch (error) {
          // Um projeto ilegível não impede limpar os outros. Se ele voltar a
          // ser lido um dia, a categoria inexistente aparece como "sem
          // categoria" (ver DrawingProject.categoryId).
          debugPrint('Vínculo não limpo em ${entity.path}: $error');
        }
      }
      return changed;
    });
  }

  Future<DrawingProject> _readProject(File file) async {
    final json = jsonDecode(await file.readAsString());
    return DrawingProject.fromJson(json as Map<String, Object?>);
  }

  @override
  Future<void> delete(DrawingProject project) {
    return _serialized(() async {
      final dir = _projectDir(project.id);
      if (await dir.exists()) await dir.delete(recursive: true);
    });
  }

  // -------------------------------------------------------------------------
  // Detalhes
  // -------------------------------------------------------------------------

  /// Grava o JSON de forma ATÔMICA: escreve num arquivo temporário e depois
  /// renomeia. Renomear dentro da mesma pasta é uma operação atômica no
  /// sistema de arquivos do Android. Se o app morrer no meio, sobra o JSON
  /// antigo inteiro, nunca um JSON pela metade (que perderia o projeto).
  Future<void> _writeProject(Directory dir, DrawingProject project) async {
    final temp = _file(dir, '$_projectFile.tmp');
    await temp.writeAsString(jsonEncode(project.toJson()), flush: true);
    await temp.rename(_file(dir, _projectFile).path);
  }

  Directory _projectDir(String id) {
    // O id vira nome de pasta. Validar impede caminhos como "../outra".
    if (!DrawingProject.validId.hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'id de projeto inválido');
    }
    return Directory('${root.path}${Platform.pathSeparator}$id');
  }

  File _file(Directory dir, String name) =>
      File('${dir.path}${Platform.pathSeparator}$name');

  /// Id curto, único e ordenável: instante em microssegundos + um número
  /// aleatório (evita colisão se dois projetos forem criados no mesmo
  /// instante). Base 36 = só `0-9a-z`, o que casa com [DrawingProject.validId].
  String _newId(DateTime now) {
    final time = now.microsecondsSinceEpoch.toRadixString(36);
    final noise = _random.nextInt(1 << 32).toRadixString(36).padLeft(7, '0');
    return '$time$noise';
  }

  /// Extensão do arquivo original, só se for "segura" (letras/números, até
  /// 5 caracteres). O Flutter identifica o formato pelo CONTEÚDO, então a
  /// extensão é só informativa.
  static String _safeExtension(String name) {
    final dot = name.lastIndexOf('.');
    final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]{1,5}$').hasMatch(ext) ? ext : 'img';
  }

  static Future<void> _deleteQuietly(Directory dir) async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (error) {
      debugPrint('Não foi possível limpar ${dir.path}: $error');
    }
  }
}
