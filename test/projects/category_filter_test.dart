// Fase 5 (Etapa 5B): filtro por categoria e filtro COMBINADO com a busca
// (lógica pura, sem telas).
import 'package:desenha_ai/features/projects/models/category_filter.dart';
import 'package:desenha_ai/features/projects/models/project_search.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

void main() {
  final animais = sampleCategory(id: 'c1', name: 'Animais');
  final retratos = sampleCategory(id: 'c2', name: 'Retratos');
  final byId = {animais.id: animais, retratos.id: retratos};

  final projects = [
    sampleProject(id: 'gato', name: 'gato.png', categoryId: 'c1'),
    sampleProject(
      id: 'cao',
      name: 'IMG_9.jpg',
      customName: 'Cão bravo',
      categoryId: 'c1',
    ),
    sampleProject(id: 'rosto', name: 'rosto gato.png', categoryId: 'c2'),
    sampleProject(id: 'solto', name: 'gato solto.png'),
    sampleProject(id: 'orfao', name: 'orfao.png', categoryId: 'apagada'),
  ];

  List<String> ids(String query, CategoryFilter filter) => applyHistoryFilters(
        projects,
        query: query,
        categoryFilter: filter,
        categoriesById: byId,
      ).map((p) => p.id).toList();

  group('CategoryFilter', () {
    test('começa inativo; marcar e desmarcar alternam', () {
      expect(CategoryFilter.none.isActive, isFalse);

      final f = CategoryFilter.none.toggleCategory('c1').toggleUncategorized();
      expect(f.isActive, isTrue);
      expect(f.count, 2);
      expect(f.isSelected('c1'), isTrue);

      final back = f.toggleCategory('c1').toggleUncategorized();
      expect(back, CategoryFilter.none);
    });

    test('== não depende da ordem em que as categorias foram marcadas', () {
      final a = CategoryFilter.none.toggleCategory('c1').toggleCategory('c2');
      final b = CategoryFilter.none.toggleCategory('c2').toggleCategory('c1');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('retainOnly tira categorias que não existem mais', () {
      final f = CategoryFilter.none
          .toggleCategory('c1')
          .toggleCategory('apagada')
          .toggleUncategorized();
      final kept = f.retainOnly(['c1', 'c2']);
      expect(kept.categoryIds, {'c1'});
      expect(kept.includeUncategorized, isTrue);
      // Nada a tirar: devolve o mesmo objeto (o notifier não dispara).
      expect(identical(kept.retainOnly(['c1']), kept), isTrue);
    });

    test('selectAll marca todas as categorias passadas', () {
      final f = CategoryFilter.none.selectAll(['c1', 'c2', 'c3']);
      expect(f.categoryIds, {'c1', 'c2', 'c3'});
      expect(f.includeUncategorized, isFalse);
      expect(f.count, 3);
    });

    test('selectAll SOMA: não desmarca categorias nem "Sem categoria"', () {
      // c3 marcada antes e "escondida" pela pesquisa continua marcada.
      final before =
          CategoryFilter.none.toggleCategory('c3').toggleUncategorized();
      final f = before.selectAll(['c1', 'c2']);
      expect(f.categoryIds, {'c1', 'c2', 'c3'});
      expect(f.includeUncategorized, isTrue);
    });

    test('selectAll sem nada novo devolve a mesma instância', () {
      final f = CategoryFilter.none.selectAll(['c1', 'c2']);
      expect(identical(f.selectAll(['c2', 'c1']), f), isTrue);
      expect(identical(f.selectAll(const []), f), isTrue);
    });

    test('containsAll diz se todas as exibidas já estão marcadas', () {
      final f = CategoryFilter.none.selectAll(['c1', 'c2']);
      expect(f.containsAll(['c1']), isTrue);
      expect(f.containsAll(['c1', 'c2']), isTrue);
      expect(f.containsAll(['c1', 'c3']), isFalse);
      expect(f.containsAll(const []), isTrue);
    });
  });

  group('filtro combinado (categorias + busca)', () {
    test('sem filtro: igual à Fase 4 (todos + busca por nome)', () {
      expect(ids('', CategoryFilter.none), hasLength(5));
      expect(
        ids('gato', CategoryFilter.none),
        ['gato', 'rosto', 'solto'],
      );
    });

    test('uma categoria: só os desenhos dela', () {
      final f = CategoryFilter.none.toggleCategory('c1');
      expect(ids('', f), ['gato', 'cao']);
    });

    test('a busca do topo procura SÓ dentro das categorias marcadas', () {
      final f = CategoryFilter.none.toggleCategory('c1');
      // "gato" existe em 3 desenhos, mas só 1 é de Animais.
      expect(ids('gato', f), ['gato']);
    });

    test('dentro do filtro, a busca mantém a prioridade de nomes', () {
      final f = CategoryFilter.none.toggleCategory('c1');
      expect(ids('cao', f), ['cao']); // nome customizado "Cão bravo"
      expect(ids('IMG_9', f), isEmpty); // nome original não é usado
    });

    test('várias categorias: união', () {
      final f = CategoryFilter.none.toggleCategory('c1').toggleCategory('c2');
      expect(ids('', f), ['gato', 'cao', 'rosto']);
      expect(ids('gato', f), ['gato', 'rosto']);
    });

    test('"Sem categoria": só os sem categoria (inclui categoria apagada)',
        () {
      final f = CategoryFilter.none.toggleUncategorized();
      expect(ids('', f), ['solto', 'orfao']);
      // A busca continua funcionando sobre esse conjunto.
      expect(ids('gato', f), ['solto']);
    });

    test('categoria + "Sem categoria": união dos dois conjuntos', () {
      final f = CategoryFilter.none.toggleCategory('c2').toggleUncategorized();
      expect(ids('', f), ['rosto', 'solto', 'orfao']);
      expect(ids('gato', f), ['rosto', 'solto']);
    });
  });
}
