// Implementações falsas dos serviços, compartilhadas entre os testes.
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:desenha_ai/features/drawing/models/drawing_settings.dart';
import 'package:desenha_ai/features/drawing/services/camera_service.dart';
import 'package:desenha_ai/features/drawing/services/screen_wake_lock.dart';
import 'package:desenha_ai/features/image_selection/data/local_image_source.dart';
import 'package:desenha_ai/features/projects/models/drawing_project.dart';
import 'package:desenha_ai/features/projects/models/project_category.dart';
import 'package:desenha_ai/features/projects/models/project_search.dart';
import 'package:desenha_ai/features/projects/models/project_status.dart';
import 'package:desenha_ai/features/projects/services/category_repository.dart';
import 'package:desenha_ai/features/projects/services/project_repository.dart';
import 'package:desenha_ai/features/theme/services/theme_controller.dart';
import 'package:desenha_ai/features/theme/services/theme_preference_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fonte de imagens falsa.
///
/// - `FakeImageSource(() async => imagem)`: escolhe UMA imagem (ou `null` =
///   cancelou). Mantém os testes antigos, de antes da seleção múltipla.
/// - `FakeImageSource.many(() async => [a, b, c])`: escolhe várias (lista
///   vazia = cancelou).
class FakeImageSource implements LocalImageSource {
  FakeImageSource(Future<PickedImage?> Function() onPick)
      : onPickMany = _single(onPick);

  FakeImageSource.many(this.onPickMany);

  Future<List<PickedImage>> Function() onPickMany;

  /// Quantas vezes o seletor foi aberto.
  int calls = 0;

  /// Troca a próxima escolha por uma imagem só (ou `null` = cancelou).
  set onPick(Future<PickedImage?> Function() onPick) =>
      onPickMany = _single(onPick);

  static Future<List<PickedImage>> Function() _single(
    Future<PickedImage?> Function() onPick,
  ) =>
      () async {
        final image = await onPick();
        return image == null ? const [] : [image];
      };

  @override
  Future<List<PickedImage>> pickImages() {
    calls++;
    return onPickMany();
  }
}

/// Câmera falsa: `start` vai direto para o estado escolhido em [onStart],
/// sem hardware nem permissão. Conta as chamadas para os testes verificarem
/// o ciclo de vida.
class FakeCameraService implements CameraService {
  FakeCameraService({CameraStatus Function()? onStart, this.torchSupported = false})
      : onStart = onStart ?? (() => const CameraOff());

  CameraStatus Function() onStart;
  final bool torchSupported;

  final _status = ValueNotifier<CameraStatus>(const CameraOff());
  final _torchOn = ValueNotifier<bool>(false);

  int startCalls = 0;
  int stopCalls = 0;
  bool disposed = false;

  @override
  ValueListenable<CameraStatus> get status => _status;

  @override
  ValueListenable<bool> get torchOn => _torchOn;

  @override
  Future<void> start() async {
    startCalls++;
    _status.value = onStart();
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _torchOn.value = false;
    _status.value = const CameraOff();
  }

  @override
  Future<bool> setTorch(bool on) async {
    if (!torchSupported) return false;
    _torchOn.value = on;
    return true;
  }

  @override
  void dispose() {
    disposed = true;
    _status.dispose();
    _torchOn.dispose();
  }
}

/// Histórico em memória. Guarda os bytes das imagens num mapa e registra
/// cada gravação em [saves] para os testes conferirem o salvamento
/// automático.
class FakeProjectRepository implements ProjectRepository {
  FakeProjectRepository({List<DrawingProject> initial = const []}) {
    for (final p in initial) {
      _projects[p.id] = p;
      _images[p.id] = pngBytes;
    }
  }

  final _projects = <String, DrawingProject>{};
  final _images = <String, Uint8List>{};
  final saves = <DrawingProject>[];
  final deleted = <String>[];
  var _nextId = 0;

  /// Relógio controlado: cada chamada avança 1 minuto, para a ordem do
  /// histórico ser previsível.
  var _now = DateTime(2025, 1, 1, 12);
  DateTime _tick() => _now = _now.add(const Duration(minutes: 1));

  /// Projeto atual guardado (para conferir ajustes salvos).
  DrawingProject? operator [](String id) => _projects[id];

  /// Se devolver `true` para um nome, `create` falha (ex.: disco cheio).
  bool Function(String originalName)? failCreate;

  /// Nomes passados a `create`, na ordem (inclusive os que falharam).
  final createCalls = <String>[];

  @override
  Future<DrawingProject> create({
    required String originalName,
    required Uint8List imageBytes,
  }) async {
    createCalls.add(originalName);
    if (failCreate?.call(originalName) ?? false) {
      throw const FileSystemException('disco cheio');
    }
    final now = _tick();
    final project = DrawingProject(
      id: 'p${_nextId++}',
      originalName: originalName,
      imageFileName: 'image.png',
      thumbnailFileName: null,
      createdAt: now,
      updatedAt: now,
    );
    _projects[project.id] = project;
    _images[project.id] = imageBytes;
    return project;
  }

  @override
  Future<List<DrawingProject>> listRecent() async =>
      _projects.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Future<Uint8List> readImage(DrawingProject project) async {
    final bytes = _images[project.id];
    if (bytes == null) throw ProjectNotFoundException(project.id);
    return bytes;
  }

  @override
  File? thumbnailFile(DrawingProject project) => null;

  @override
  Future<DrawingProject> save(DrawingProject project) async {
    if (!_projects.containsKey(project.id)) {
      throw ProjectNotFoundException(project.id);
    }
    final updated = project.copyWith(updatedAt: _tick());
    _projects[project.id] = updated;
    saves.add(updated);
    return updated;
  }

  /// Cada chamada a `updateDetails`, na ordem (para os testes conferirem).
  final edits = <({String? customName, String? categoryId})>[];

  @override
  Future<DrawingProject> updateDetails(
    DrawingProject project, {
    required String? customName,
    required String? categoryId,
  }) async {
    final current = _projects[project.id];
    if (current == null) throw ProjectNotFoundException(project.id);
    edits.add((customName: customName, categoryId: categoryId));
    // Como o repositório real: parte do estado guardado e não muda o
    // "último acesso".
    final updated = current.rename(customName).withCategory(categoryId);
    _projects[project.id] = updated;
    return updated;
  }

  /// Cada status gravado por `updateStatus`, na ordem.
  final statusChanges = <({String id, ProjectStatus status})>[];

  @override
  Future<DrawingProject> updateStatus(
    DrawingProject project,
    ProjectStatus status,
  ) async {
    final current = _projects[project.id];
    if (current == null) throw ProjectNotFoundException(project.id);
    statusChanges.add((id: project.id, status: status));
    // Como o repositório real: parte do estado guardado e não muda o
    // "último acesso".
    final updated = current.withStatus(status);
    _projects[project.id] = updated;
    return updated;
  }

  @override
  Future<int> clearCategory(String categoryId) async {
    var changed = 0;
    for (final entry in _projects.entries.toList()) {
      if (entry.value.categoryId != categoryId) continue;
      _projects[entry.key] = entry.value.withCategory(null);
      changed++;
    }
    return changed;
  }

  @override
  Future<void> delete(DrawingProject project) async {
    _projects.remove(project.id);
    _images.remove(project.id);
    deleted.add(project.id);
  }
}

/// Categorias em memória, com a MESMA validação do repositório real
/// (`validateCategoryName`), para os testes de tela verem as mesmas regras.
class FakeCategoryRepository implements CategoryRepository {
  FakeCategoryRepository({List<ProjectCategory> initial = const []})
      : _categories = [...initial];

  final List<ProjectCategory> _categories;
  final deleted = <String>[];
  var _nextId = 0;

  @override
  Future<List<ProjectCategory>> listAll() async => [..._categories]
    ..sort((a, b) => normalizeForSearch(a.name).compareTo(
          normalizeForSearch(b.name),
        ));

  @override
  Future<ProjectCategory> create({
    required String name,
    required int colorValue,
  }) async {
    final error = validateCategoryName(name, _categories);
    if (error != null) throw CategoryValidationException(error);
    final category = ProjectCategory(
      id: 'c${_nextId++}',
      name: name.trim(),
      colorValue: colorValue,
    );
    _categories.add(category);
    return category;
  }

  @override
  Future<void> delete(ProjectCategory category) async {
    _categories.removeWhere((c) => c.id == category.id);
    deleted.add(category.id);
  }

  /// Cada `update` feito (para os testes conferirem).
  final updates = <ProjectCategory>[];

  @override
  Future<ProjectCategory> update(
    ProjectCategory category, {
    required String name,
    required int colorValue,
  }) async {
    final index = _categories.indexWhere((c) => c.id == category.id);
    if (index < 0) throw CategoryNotFoundException(category.id);
    final error =
        validateCategoryName(name, _categories, exceptId: category.id);
    if (error != null) throw CategoryValidationException(error);
    final updated = ProjectCategory(
      id: category.id,
      name: name.trim(),
      colorValue: colorValue,
    );
    _categories[index] = updated;
    updates.add(updated);
    return updated;
  }
}

/// Categoria de exemplo para testes.
ProjectCategory sampleCategory({
  String id = 'c1',
  String name = 'Animais',
  int colorValue = 0xFF43A047,
}) =>
    ProjectCategory(id: id, name: name, colorValue: colorValue);

/// Projeto de exemplo para testes.
DrawingProject sampleProject({
  String id = 'p1',
  String name = 'ref.png',
  String? customName,
  String? categoryId,
  ProjectStatus status = ProjectStatus.initial,
  DrawingSettings settings = const DrawingSettings(),
  DateTime? updatedAt,
}) {
  final date = updatedAt ?? DateTime(2025, 1, 1, 10);
  return DrawingProject(
    id: id,
    originalName: name,
    customName: customName,
    categoryId: categoryId,
    status: status,
    imageFileName: 'image.png',
    thumbnailFileName: null,
    createdAt: date,
    updatedAt: date,
    settings: settings,
  );
}

/// Preferência de tema em memória (Fase 6). [saved] é o que estaria no
/// disco; [saves] conta as gravações; [failOnSave] simula disco cheio.
class FakeThemePreferenceStore implements ThemePreferenceStore {
  FakeThemePreferenceStore({this.saved, this.failOnSave = false});

  Brightness? saved;
  bool failOnSave;
  int saves = 0;

  @override
  Future<Brightness?> load() async => saved;

  @override
  Future<void> save(Brightness brightness) async {
    saves++;
    if (failOnSave) throw const FileSystemException('disco cheio');
    saved = brightness;
  }
}

/// Controlador de tema para os testes que não ligam para o tema: começa no
/// modo do sistema e grava em memória.
ThemeController fakeThemeController() =>
    ThemeController(store: FakeThemePreferenceStore());

/// Wakelock falso: guarda se está ligado e quantas vezes foi chamado.
class FakeScreenWakeLock implements ScreenWakeLock {
  bool enabled = false;
  int enableCalls = 0;
  int disableCalls = 0;

  @override
  Future<void> enable() async {
    enableCalls++;
    enabled = true;
  }

  @override
  Future<void> disable() async {
    disableCalls++;
    enabled = false;
  }
}

/// Estado "câmera pronta" para testes. Criar um `CameraController` não toca
/// no hardware; só `initialize()` faria isso, e não chamamos.
CameraReady fakeReadyStatus() => CameraReady(
      CameraController(
        const CameraDescription(
          name: 'fake',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 90,
        ),
        ResolutionPreset.high,
        enableAudio: false,
      ),
    );

/// PNG válido de 1x1 pixel.
final pngBytes = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Avança o tempo o suficiente para terminar transições (fade, troca de
/// rota). Não usamos `pumpAndSettle` porque indicadores de progresso e a
/// decodificação de imagem nunca "assentam" no relógio falso dos testes.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}
