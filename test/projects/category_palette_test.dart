// Etapa 6D: paleta de 30 cores e edição de categorias no repositório REAL
// (pasta temporária).
import 'dart:io';
import 'dart:math' as math;

import 'package:desenha_ai/features/projects/models/project_category.dart';
import 'package:desenha_ai/features/projects/services/file_category_repository.dart';
import 'package:desenha_ai/features/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Razão de contraste do WCAG entre duas cores.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

/// Distância entre duas cores no espaço RGB (0–255 por canal).
double _distance(int a, int b) {
  int ch(int v, int shift) => (v >> shift) & 0xFF;
  final dr = ch(a, 16) - ch(b, 16);
  final dg = ch(a, 8) - ch(b, 8);
  final db = ch(a, 0) - ch(b, 0);
  return math.sqrt(dr * dr + dg * dg + db * db);
}

void main() {
  group('paleta de 30 cores', () {
    test('tem exatamente 30 cores, todas diferentes e com nomes únicos', () {
      expect(categoryPalette, hasLength(30));
      expect(categoryPalette.map((c) => c.value).toSet(), hasLength(30));
      expect(categoryPalette.map((c) => c.name).toSet(), hasLength(30));
    });

    test('as 12 cores da Etapa 5A continuam na mesma ordem e valor', () {
      // Categorias antigas não podem mudar de cor.
      expect(
        categoryPalette.take(12).map((c) => c.value).toList(),
        const [
          0xFFE53935, 0xFFD81B60, 0xFF8E24AA, 0xFF3949AB, //
          0xFF1E88E5, 0xFF00ACC1, 0xFF00897B, 0xFF43A047,
          0xFF9E9D24, 0xFFFFB300, 0xFFF4511E, 0xFF6D4C41,
        ],
      );
    });

    test('todas são opacas', () {
      for (final c in categoryPalette) {
        expect(c.value >> 24, 0xFF, reason: c.name);
      }
    });

    test('nenhuma some no fundo claro nem no escuro', () {
      // As cores aparecem como bolinha + borda na badge e no seletor (o
      // TEXTO usa a cor do tema). 1,5 garante que a bolinha se destaca do
      // card nos dois modos, mesmo nos tons mais claros (Pêssego, Âmbar) e
      // mais escuros (Vinho, Grafite).
      final light = AppTheme.light.colorScheme.surface;
      final dark = AppTheme.dark.colorScheme.surface;
      for (final c in categoryPalette) {
        final color = Color(c.value);
        expect(_contrast(color, light), greaterThan(1.5), reason: c.name);
        expect(_contrast(color, dark), greaterThan(1.5), reason: c.name);
      }
    });

    test('bem distribuídas: não há duas cores quase iguais', () {
      var closest = double.infinity;
      String? pair;
      for (var i = 0; i < categoryPalette.length; i++) {
        for (var j = i + 1; j < categoryPalette.length; j++) {
          final d =
              _distance(categoryPalette[i].value, categoryPalette[j].value);
          if (d < closest) {
            closest = d;
            pair = '${categoryPalette[i].name} × ${categoryPalette[j].name}';
          }
        }
      }
      expect(closest, greaterThan(35), reason: 'par mais próximo: $pair');
    });
  });

  group('validateCategoryName ao editar', () {
    const animais =
        ProjectCategory(id: 'c1', name: 'Animais', colorValue: 0xFF43A047);
    const retratos =
        ProjectCategory(id: 'c2', name: 'Retratos', colorValue: 0xFF1E88E5);

    test('a própria categoria não conta como duplicada', () {
      expect(
        validateCategoryName('animais', [animais, retratos], exceptId: 'c1'),
        isNull,
      );
    });

    test('o nome de OUTRA categoria continua proibido', () {
      expect(
        validateCategoryName('Retratos', [animais, retratos], exceptId: 'c1'),
        CategoryNameError.duplicate,
      );
    });
  });

  group('FileCategoryRepository.update', () {
    late Directory temp;
    late File file;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('desenha_ai_cat_edit');
      file = File('${temp.path}${Platform.pathSeparator}categories.json');
    });

    tearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    test('muda nome e cor, mantém o id e grava no disco', () async {
      final repo = FileCategoryRepository(file: file);
      final animais = await repo.create(name: 'Animais', colorValue: 0xFF43A047);

      final updated = await repo.update(
        animais,
        name: '  Bichos ',
        colorValue: 0xFF3D5AFE,
      );
      expect(updated.id, animais.id);
      expect(updated.name, 'Bichos');
      expect(updated.colorValue, 0xFF3D5AFE);

      // Repositório NOVO = app reaberto.
      final reloaded = (await FileCategoryRepository(file: file).listAll())
          .single;
      expect(reloaded, updated);
    });

    test('pode trocar só a cor, ou só maiúsculas do próprio nome', () async {
      final repo = FileCategoryRepository(file: file);
      final c = await repo.create(name: 'animais', colorValue: 0xFF43A047);
      final a = await repo.update(c, name: 'animais', colorValue: 0xFFE53935);
      expect(a.colorValue, 0xFFE53935);
      final b = await repo.update(a, name: 'Animais', colorValue: a.colorValue);
      expect(b.name, 'Animais');
    });

    test('recusa nome vazio ou de outra categoria, sem gravar', () async {
      final repo = FileCategoryRepository(file: file);
      final a = await repo.create(name: 'Animais', colorValue: 0xFF43A047);
      await repo.create(name: 'Retratos', colorValue: 0xFF1E88E5);

      await expectLater(
        repo.update(a, name: '   ', colorValue: a.colorValue),
        throwsA(isA<CategoryValidationException>()),
      );
      await expectLater(
        repo.update(a, name: 'retratos', colorValue: a.colorValue),
        throwsA(
          isA<CategoryValidationException>().having(
            (e) => e.error,
            'error',
            CategoryNameError.duplicate,
          ),
        ),
      );
      expect(
        (await repo.listAll()).map((c) => c.name),
        ['Animais', 'Retratos'],
      );
    });

    test('categoria removida não pode ser editada', () async {
      final repo = FileCategoryRepository(file: file);
      final a = await repo.create(name: 'Animais', colorValue: 0xFF43A047);
      await repo.delete(a);
      await expectLater(
        repo.update(a, name: 'Bichos', colorValue: a.colorValue),
        throwsA(isA<CategoryNotFoundException>()),
      );
      expect(await repo.listAll(), isEmpty);
    });
  });
}
