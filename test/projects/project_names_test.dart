// Fase 4: prioridade de nomes, renomeação no modelo e busca (lógica pura).
import 'dart:convert';

import 'package:desenha_ai/features/projects/models/drawing_project.dart';
import 'package:desenha_ai/features/projects/models/project_search.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

void main() {
  group('displayName: customizado > original > padrão', () {
    test('1º usa o nome customizado', () {
      final p = sampleProject(name: 'IMG_2025.jpg', customName: 'Gato azul');
      expect(p.displayName, 'Gato azul');
    });

    test('2º sem customizado, usa o nome original do arquivo', () {
      expect(sampleProject(name: 'IMG_2025.jpg').displayName, 'IMG_2025.jpg');
    });

    test('3º sem nenhum dos dois, usa o padrão do sistema', () {
      expect(sampleProject(name: '').displayName, DrawingProject.fallbackName);
      expect(sampleProject(name: '   ').displayName, 'Imagem');
    });

    test('nome customizado só com espaços é ignorado', () {
      final p = sampleProject(name: 'a.png', customName: '   ');
      expect(p.displayName, 'a.png');
    });
  });

  group('rename (modelo)', () {
    final original = sampleProject(name: 'gato.jpg');

    test('guarda o nome sem espaços nas pontas', () {
      expect(original.rename('  Meu gato  ').customName, 'Meu gato');
    });

    test('vazio ou só espaços limpa o nome (volta ao original)', () {
      final renamed = original.rename('Meu gato');
      expect(renamed.rename('').customName, isNull);
      expect(renamed.rename('    ').customName, isNull);
      expect(renamed.rename(null).displayName, 'gato.jpg');
    });

    test('igual ao nome original vira "sem nome customizado"', () {
      expect(original.rename('gato.jpg').customName, isNull);
    });

    test('nomes longos são cortados no limite', () {
      final long = 'x' * (DrawingProject.maxCustomNameLength + 20);
      expect(
        original.rename(long).customName!.length,
        DrawingProject.maxCustomNameLength,
      );
    });

    test('não mexe em mais nada (arquivos, datas, ajustes)', () {
      final renamed = original.rename('Novo');
      expect(renamed.originalName, original.originalName);
      expect(renamed.imageFileName, original.imageFileName);
      expect(renamed.updatedAt, original.updatedAt);
      expect(renamed.settings, original.settings);
    });

    test('copyWith (salvamento automático) preserva o nome customizado', () {
      final renamed = original.rename('Novo');
      expect(
        renamed.copyWith(updatedAt: DateTime(2030)).customName,
        'Novo',
      );
    });
  });

  group('JSON do nome customizado', () {
    Map<String, Object?> roundTrip(DrawingProject p) =>
        jsonDecode(jsonEncode(p.toJson())) as Map<String, Object?>;

    test('ida e volta sem perda', () {
      final p = sampleProject(customName: 'Gato azul');
      expect(DrawingProject.fromJson(roundTrip(p)), p);
    });

    test('project.json da Fase 3 (sem customName) continua válido', () {
      final json = roundTrip(sampleProject(name: 'gato.jpg'))
        ..remove('customName');
      final p = DrawingProject.fromJson(json);
      expect(p.customName, isNull);
      expect(p.displayName, 'gato.jpg');
    });

    test('customName em branco no arquivo vira null', () {
      final json = roundTrip(sampleProject())..['customName'] = '   ';
      expect(DrawingProject.fromJson(json).customName, isNull);
    });

    test('sem originalName no arquivo, exibe o nome padrão', () {
      final json = roundTrip(sampleProject())..remove('originalName');
      expect(DrawingProject.fromJson(json).displayName, 'Imagem');
    });
  });

  group('filterProjects (busca)', () {
    final projects = [
      sampleProject(id: 'a', name: 'IMG_001.jpg', customName: 'Pássaro azul'),
      sampleProject(id: 'b', name: 'gato.png'),
      sampleProject(id: 'c', name: ''),
    ];

    List<String> ids(String query) =>
        filterProjects(projects, query).map((p) => p.id).toList();

    test('texto vazio devolve tudo, na mesma ordem', () {
      expect(ids(''), ['a', 'b', 'c']);
      expect(ids('   '), ['a', 'b', 'c']);
    });

    test('busca pelo nome customizado', () {
      expect(ids('pássaro'), ['a']);
    });

    test('com nome customizado, o nome original NÃO é usado na busca', () {
      // A busca segue o que o usuário vê na lista.
      expect(ids('IMG_001'), isEmpty);
    });

    test('sem customizado, busca pelo nome original', () {
      expect(ids('gato'), ['b']);
    });

    test('sem nenhum nome, busca pelo nome padrão', () {
      expect(ids('imagem'), ['c']);
    });

    test('ignora maiúsculas e acentos', () {
      expect(ids('PASSARO'), ['a']);
      expect(ids('GaTo'), ['b']);
    });

    test('várias palavras, em qualquer ordem', () {
      expect(ids('azul passaro'), ['a']);
      expect(ids('azul gato'), isEmpty);
    });
  });
}
