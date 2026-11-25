// Status dos desenhos (etapa final), sem widgets: enum, JSON retrocompatível,
// filtro de status, filtro combinado, repositório real e contraste das cores.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:desenha_ai/features/drawing/models/drawing_settings.dart';
import 'package:desenha_ai/features/projects/models/category_filter.dart';
import 'package:desenha_ai/features/projects/models/drawing_project.dart';
import 'package:desenha_ai/features/projects/models/project_search.dart';
import 'package:desenha_ai/features/projects/models/project_status.dart';
import 'package:desenha_ai/features/projects/models/status_filter.dart';
import 'package:desenha_ai/features/projects/services/file_project_repository.dart';
import 'package:desenha_ai/features/projects/services/project_repository.dart';
import 'package:desenha_ai/features/projects/services/thumbnail_generator.dart';
import 'package:desenha_ai/features/projects/widgets/project_status_style.dart';
import 'package:desenha_ai/features/theme/app_palette.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../fakes.dart';

class _FakeThumbnails implements ThumbnailGenerator {
  @override
  Future<Uint8List> generate(Uint8List imageBytes) async =>
      Uint8List.fromList([1, 2, 3]);
}

/// Contraste WCAG entre duas cores (1:1 a 21:1).
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('ProjectStatus', () {
    test('os 4 status, na ordem, com os nomes da tela', () {
      expect(ProjectStatus.values.map((s) => s.label),
          ['Não iniciado', 'Em andamento', 'Concluído', 'Arquivado']);
      expect(ProjectStatus.initial, ProjectStatus.notStarted);
    });

    test('lê o valor do JSON; ausente ou desconhecido vira "Não iniciado"',
        () {
      for (final s in ProjectStatus.values) {
        expect(ProjectStatus.fromJson(s.jsonValue), s);
      }
      expect(ProjectStatus.fromJson(null), ProjectStatus.notStarted);
      expect(ProjectStatus.fromJson('pausado'), ProjectStatus.notStarted);
      expect(ProjectStatus.fromJson(3), ProjectStatus.notStarted);
    });
  });

  group('DrawingProject.status', () {
    final project = sampleProject(status: ProjectStatus.done);

    test('padrão é "Não iniciado"', () {
      expect(sampleProject().status, ProjectStatus.notStarted);
    });

    test('ida e volta pelo JSON sem perda', () {
      final json =
          jsonDecode(jsonEncode(project.toJson())) as Map<String, Object?>;
      expect(json['status'], 'done');
      expect(DrawingProject.fromJson(json), project);
    });

    test('JSON antigo, sem o campo, abre como "Não iniciado"', () {
      final old = project.toJson()..remove('status');
      final restored = DrawingProject.fromJson(old);
      expect(restored.status, ProjectStatus.notStarted);
      // O resto do projeto continua intacto.
      expect(restored.id, project.id);
      expect(restored.settings, project.settings);
    });

    test('o schemaVersion continua 1 (campo opcional)', () {
      expect(DrawingProject.schemaVersion, 1);
      expect(project.toJson()['schemaVersion'], 1);
    });

    test('withStatus troca só o status (nem o último acesso)', () {
      final p = sampleProject(customName: 'Gato', categoryId: 'c1');
      final changed = p.withStatus(ProjectStatus.archived);
      expect(changed.status, ProjectStatus.archived);
      expect(changed.customName, 'Gato');
      expect(changed.categoryId, 'c1');
      expect(changed.updatedAt, p.updatedAt);
      expect(changed, isNot(p)); // `==` considera o status
    });

    test('renomear, trocar categoria e salvar ajustes mantêm o status', () {
      final p = sampleProject(status: ProjectStatus.inProgress);
      expect(p.rename('Novo').status, ProjectStatus.inProgress);
      expect(p.withCategory('c2').status, ProjectStatus.inProgress);
      expect(
        p
            .copyWith(
              settings: const DrawingSettings(opacity: 0.3),
              updatedAt: DateTime(2030),
            )
            .status,
        ProjectStatus.inProgress,
      );
    });
  });

  group('StatusFilter', () {
    test('começa com "Todos": nenhum específico marcado, mostra todos', () {
      expect(StatusFilter.initial, StatusFilter.none);
      expect(StatusFilter.initial.statuses, isEmpty);
      expect(StatusFilter.initial.isActive, isFalse);
      expect(StatusFilter.initial.showsAll, isTrue);
      for (final s in ProjectStatus.values) {
        expect(StatusFilter.initial.matches(sampleProject(status: s)), isTrue);
      }
    });

    test('toggle marca e desmarca; vários ao mesmo tempo', () {
      final f = StatusFilter.initial
          .toggle(ProjectStatus.notStarted)
          .toggle(ProjectStatus.done);
      expect(f.statuses, {ProjectStatus.notStarted, ProjectStatus.done});
      expect(f.toggle(ProjectStatus.notStarted).statuses,
          {ProjectStatus.done});
    });

    test('"Todos": marcado no início e só quando não há status específico',
        () {
      expect(StatusFilter.initial.showsAll, isTrue);
      expect(StatusFilter.none.showsAll, isTrue);
      // Marcar um específico a partir de "Todos" desmarca "Todos".
      final one = StatusFilter.none.toggle(ProjectStatus.done);
      expect(one.showsAll, isFalse);
      expect(one.statuses, {ProjectStatus.done});
      // Desmarcar o último específico volta a "Todos".
      expect(one.toggle(ProjectStatus.done).showsAll, isTrue);
      // Com dois marcados, tirar um não volta a "Todos".
      final two = one.toggle(ProjectStatus.archived);
      expect(two.toggle(ProjectStatus.done).showsAll, isFalse);
    });

    test('nada marcado = mostra todos', () {
      // Marca e desmarca o único: volta ao vazio.
      final none = StatusFilter.initial
          .toggle(ProjectStatus.notStarted)
          .toggle(ProjectStatus.notStarted);
      expect(none, StatusFilter.none);
      for (final s in ProjectStatus.values) {
        expect(none.matches(sampleProject(status: s)), isTrue);
      }
    });

    test('matches segue os marcados', () {
      const f = StatusFilter({ProjectStatus.notStarted, ProjectStatus.done});
      expect(f.matches(sampleProject()), isTrue);
      expect(f.matches(sampleProject(status: ProjectStatus.done)), isTrue);
      expect(f.matches(sampleProject(status: ProjectStatus.archived)),
          isFalse);
    });

    test('including soma sem desmarcar e reaproveita a instância', () {
      const onlyDone = StatusFilter({ProjectStatus.done});
      expect(onlyDone.including(ProjectStatus.notStarted).statuses,
          {ProjectStatus.done, ProjectStatus.notStarted});
      const onlyNotStarted = StatusFilter({ProjectStatus.notStarted});
      expect(identical(onlyNotStarted.including(ProjectStatus.notStarted),
          onlyNotStarted), isTrue);
      expect(identical(StatusFilter.none.including(ProjectStatus.done),
          StatusFilter.none), isTrue);
    });

    test('== e hashCode independem da ordem', () {
      final a = StatusFilter.none
          .toggle(ProjectStatus.done)
          .toggle(ProjectStatus.archived);
      final b = StatusFilter.none
          .toggle(ProjectStatus.archived)
          .toggle(ProjectStatus.done);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('filtro combinado (status + categoria + busca)', () {
    final projects = [
      sampleProject(id: 'a', name: 'gato.png', categoryId: 'c1'),
      sampleProject(
          id: 'b', name: 'gato azul.png', categoryId: 'c1',
          status: ProjectStatus.done),
      sampleProject(
          id: 'c', name: 'gato preto.png', categoryId: 'c2',
          status: ProjectStatus.done),
      sampleProject(id: 'd', name: 'casa.png', status: ProjectStatus.done),
      sampleProject(
          id: 'e', name: 'gato velho.png', categoryId: 'c1',
          status: ProjectStatus.archived),
    ];
    const categories = {'c1': 'Animais', 'c2': 'Retratos'};

    List<String> ids({
      String query = '',
      StatusFilter status = StatusFilter.none,
      CategoryFilter category = CategoryFilter.none,
    }) =>
        applyHistoryFilters(
          projects,
          query: query,
          statusFilter: status,
          categoryFilter: category,
          categoriesById: categories,
        ).map((p) => p.id).toList();

    test('sem filtros: todos', () {
      expect(ids(), ['a', 'b', 'c', 'd', 'e']);
    });

    test('padrão da Home ("Todos"): todos os status', () {
      expect(ids(status: StatusFilter.initial), ['a', 'b', 'c', 'd', 'e']);
    });

    test('só "Não iniciado"', () {
      expect(ids(status: const StatusFilter({ProjectStatus.notStarted})),
          ['a']);
    });

    test('"Todos" + categoria + busca', () {
      final animais = CategoryFilter.none.toggleCategory('c1');
      expect(ids(status: StatusFilter.initial, category: animais),
          ['a', 'b', 'e']);
      expect(
        ids(status: StatusFilter.initial, category: animais, query: 'velho'),
        ['e'],
      );
    });

    test('status + categoria + busca, todos ao mesmo tempo', () {
      const done = StatusFilter({ProjectStatus.done});
      final animais = CategoryFilter.none.toggleCategory('c1');
      expect(ids(status: done), ['b', 'c', 'd']);
      expect(ids(status: done, category: animais), ['b']);
      expect(ids(status: done, query: 'gato'), ['b', 'c']);
      expect(ids(status: done, category: animais, query: 'azul'), ['b']);
      expect(ids(status: done, category: animais, query: 'preto'), isEmpty);
    });
  });

  group('FileProjectRepository', () {
    late Directory temp;
    late FileProjectRepository repo;
    var now = DateTime(2025, 1, 1, 12);
    final image = Uint8List.fromList(List.generate(32, (i) => i));

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('desenha_ai_status');
      now = DateTime(2025, 1, 1, 12);
      repo = FileProjectRepository(
        root: Directory('${temp.path}${Platform.pathSeparator}projects'),
        thumbnails: _FakeThumbnails(),
        clock: () => now = now.add(const Duration(minutes: 1)),
      );
    });

    tearDown(() => temp.delete(recursive: true));

    File jsonOf(DrawingProject p) => File(
          '${temp.path}${Platform.pathSeparator}projects'
          '${Platform.pathSeparator}${p.id}'
          '${Platform.pathSeparator}project.json',
        );

    test('imagem nova começa como "Não iniciado" (no disco também)',
        () async {
      final p = await repo.create(originalName: 'a.png', imageBytes: image);
      expect(p.status, ProjectStatus.notStarted);
      final json = jsonDecode(await jsonOf(p).readAsString()) as Map;
      expect(json['status'], 'notStarted');
    });

    test('project.json antigo, sem "status", é lido como "Não iniciado"',
        () async {
      final p = await repo.create(originalName: 'a.png', imageBytes: image);
      final file = jsonOf(p);
      final json = jsonDecode(await file.readAsString()) as Map<String, Object?>
        ..remove('status');
      await file.writeAsString(jsonEncode(json));

      final listed = (await repo.listRecent()).single;
      expect(listed.status, ProjectStatus.notStarted);
      expect(listed.originalName, 'a.png');
    });

    test('updateStatus grava sem mudar o último acesso', () async {
      final p = await repo.create(originalName: 'a.png', imageBytes: image);
      final updated = await repo.updateStatus(p, ProjectStatus.done);

      expect(updated.status, ProjectStatus.done);
      expect(updated.updatedAt, p.updatedAt);
      final listed = (await repo.listRecent()).single;
      expect(listed.status, ProjectStatus.done);
      expect(listed.updatedAt, p.updatedAt);
    });

    test('salvar ajustes (desenho) não muda o status', () async {
      final p = await repo.create(originalName: 'a.png', imageBytes: image);
      final done = await repo.updateStatus(p, ProjectStatus.inProgress);
      await repo.save(
        done.copyWith(settings: const DrawingSettings(opacity: 0.2)),
      );
      expect((await repo.listRecent()).single.status,
          ProjectStatus.inProgress);
    });

    test('updateStatus parte do disco (não perde ajustes mais novos)',
        () async {
      final stale = await repo.create(originalName: 'a.png', imageBytes: image);
      await repo.save(
        stale.copyWith(settings: const DrawingSettings(opacity: 0.9)),
      );
      final updated = await repo.updateStatus(stale, ProjectStatus.archived);
      expect(updated.settings.opacity, 0.9);
    });

    test('renomear mantém o status gravado', () async {
      final p = await repo.create(originalName: 'a.png', imageBytes: image);
      await repo.updateStatus(p, ProjectStatus.done);
      await repo.updateDetails(p, customName: 'Novo', categoryId: null);
      expect((await repo.listRecent()).single.status, ProjectStatus.done);
    });

    test('projeto excluído: falha sem recriar', () async {
      final p = await repo.create(originalName: 'a.png', imageBytes: image);
      await repo.delete(p);
      await expectLater(
        repo.updateStatus(p, ProjectStatus.done),
        throwsA(isA<ProjectNotFoundException>()),
      );
    });
  });

  group('cores e ícones', () {
    test('cada status tem ícone próprio', () {
      final icons = ProjectStatus.values.map((s) => s.icon).toSet();
      expect(icons, hasLength(4));
    });

    test('cores distintas e com contraste ≥ 4,5:1 nos dois modos', () {
      for (final (brightness, surface) in [
        (Brightness.light, AppPalette.lightSurface),
        (Brightness.dark, AppPalette.darkSurface),
      ]) {
        final colors =
            ProjectStatus.values.map((s) => s.colorFor(brightness)).toList();
        expect(colors.toSet(), hasLength(4), reason: '$brightness');
        for (final s in ProjectStatus.values) {
          expect(
            _contrast(s.colorFor(brightness), surface),
            greaterThanOrEqualTo(4.5),
            reason: '${s.label} no modo $brightness',
          );
        }
      }
    });

    test('claro e escuro usam tons diferentes', () {
      for (final s in ProjectStatus.values) {
        expect(s.colorFor(Brightness.light),
            isNot(s.colorFor(Brightness.dark)));
      }
    });
  });
}
