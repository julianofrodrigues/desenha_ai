import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/project_category.dart';
import '../models/project_search.dart';
import 'category_repository.dart';

/// Categorias num único arquivo JSON no armazenamento interno do app.
///
/// ```json
/// {
///   "schemaVersion": 1,
///   "categories": [
///     {"id": "lq3k9x2a7f", "name": "Animais", "color": 4293212469}
///   ]
/// }
/// ```
///
/// Por que um arquivo só (e não uma pasta por categoria, como os projetos)?
/// Categorias são poucas (dezenas, no máximo) e pequenas, sem imagem. Ler e
/// gravar a lista inteira leva menos de 1 ms e é muito mais simples.
class FileCategoryRepository implements CategoryRepository {
  FileCategoryRepository({required this.file, Random? random})
      : _random = random ?? Random();

  /// No app: `<documentos do app>/categories.json` (ver `main.dart`).
  final File file;
  final Random _random;

  static const int schemaVersion = 1;

  /// Mesma ideia do `FileProjectRepository`: operações que GRAVAM entram
  /// numa fila e rodam uma de cada vez. Sem isso, criar duas categorias
  /// seguidas poderia fazer a segunda gravação apagar a primeira.
  Future<void> _writes = Future.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _writes.then((_) => action());
    _writes = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  @override
  Future<List<ProjectCategory>> listAll() async => _sorted(await _read());

  @override
  Future<ProjectCategory> create({
    required String name,
    required int colorValue,
  }) {
    return _serialized(() async {
      final categories = await _read();
      // A UI já valida, mas o repositório é a última barreira: nunca grava
      // um nome vazio ou duplicado, mesmo que outra tela esqueça de checar.
      final error = validateCategoryName(name, categories);
      if (error != null) throw CategoryValidationException(error);

      final category = ProjectCategory(
        id: _newId(),
        name: name.trim(),
        colorValue: colorValue | 0xFF000000,
      );
      await _write([...categories, category]);
      return category;
    });
  }

  @override
  Future<ProjectCategory> update(
    ProjectCategory category, {
    required String name,
    required int colorValue,
  }) {
    return _serialized(() async {
      // Parte do que está no DISCO (como o `updateDetails` dos projetos): a
      // lista da tela pode estar desatualizada.
      final categories = await _read();
      final index = categories.indexWhere((c) => c.id == category.id);
      if (index < 0) throw CategoryNotFoundException(category.id);

      final error =
          validateCategoryName(name, categories, exceptId: category.id);
      if (error != null) throw CategoryValidationException(error);

      final updated = ProjectCategory(
        id: category.id, // o id NUNCA muda: é ele que os projetos guardam
        name: name.trim(),
        colorValue: colorValue | 0xFF000000,
      );
      // Nada mudou: evita uma gravação inútil na memória flash.
      if (updated != categories[index]) {
        categories[index] = updated;
        await _write(categories);
      }
      return updated;
    });
  }

  @override
  Future<void> delete(ProjectCategory category) {
    return _serialized(() async {
      final categories = await _read();
      final remaining = categories.where((c) => c.id != category.id).toList();
      // Já não existia: nada a gravar (excluir duas vezes não é erro).
      if (remaining.length != categories.length) await _write(remaining);
    });
  }

  // -------------------------------------------------------------------------
  // Detalhes
  // -------------------------------------------------------------------------

  /// Lê o arquivo, tolerando problemas: sem arquivo = nenhuma categoria;
  /// uma categoria ilegível é pulada sem esconder as outras.
  Future<List<ProjectCategory>> _read() async {
    if (!await file.exists()) return [];
    final Object? json;
    try {
      json = jsonDecode(await file.readAsString());
    } catch (error) {
      // Arquivo corrompido: o app continua funcionando, só sem categorias.
      // Os projetos que apontavam para elas aparecem "sem categoria".
      debugPrint('categories.json ilegível: $error');
      return [];
    }
    if (json is! Map<String, Object?>) return [];
    final version = json['schemaVersion'];
    if (version is int && version > schemaVersion) {
      // Arquivo de uma versão MAIS NOVA do app: melhor não interpretar (e
      // muito menos sobrescrever com o que entendemos dele).
      throw const FormatException('categories.json de versão mais nova');
    }

    final list = json['categories'];
    if (list is! List) return [];
    final categories = <ProjectCategory>[];
    final seenIds = <String>{};
    for (final item in list) {
      try {
        final category =
            ProjectCategory.fromJson(item as Map<String, Object?>);
        // Id repetido (arquivo editado à mão): fica a primeira.
        if (seenIds.add(category.id)) categories.add(category);
      } catch (error) {
        debugPrint('Categoria ignorada: $error');
      }
    }
    return categories;
  }

  /// Gravação atômica: arquivo temporário + renomear (ver docs/04, 1.5).
  Future<void> _write(List<ProjectCategory> categories) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode({
        'schemaVersion': schemaVersion,
        'categories': [for (final c in categories) c.toJson()],
      }),
      flush: true,
    );
    await temp.rename(file.path);
  }

  static List<ProjectCategory> _sorted(List<ProjectCategory> categories) =>
      categories
        ..sort(
          (a, b) =>
              normalizeForSearch(a.name).compareTo(normalizeForSearch(b.name)),
        );

  /// Mesmo esquema dos ids de projeto: instante + número aleatório, em
  /// base 36 (casa com [ProjectCategory.validId]).
  String _newId() {
    final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final noise = _random.nextInt(1 << 32).toRadixString(36).padLeft(7, '0');
    return '$time$noise';
  }
}
