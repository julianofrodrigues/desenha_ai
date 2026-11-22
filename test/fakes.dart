// Implementações falsas dos serviços, compartilhadas entre os testes.
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:desenha_ai/features/drawing/models/drawing_settings.dart';
import 'package:desenha_ai/features/drawing/services/camera_service.dart';
import 'package:desenha_ai/features/drawing/services/screen_wake_lock.dart';
import 'package:desenha_ai/features/image_selection/data/local_image_source.dart';
import 'package:desenha_ai/features/projects/models/drawing_project.dart';
import 'package:desenha_ai/features/projects/services/project_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fonte de imagens falsa: cada chamada a `pickImage` executa [onPick].
class FakeImageSource implements LocalImageSource {
  FakeImageSource(this.onPick);

  Future<PickedImage?> Function() onPick;

  @override
  Future<PickedImage?> pickImage() => onPick();
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

  @override
  Future<DrawingProject> create({
    required String originalName,
    required Uint8List imageBytes,
  }) async {
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

  @override
  Future<void> delete(DrawingProject project) async {
    _projects.remove(project.id);
    _images.remove(project.id);
    deleted.add(project.id);
  }
}

/// Projeto de exemplo para testes.
DrawingProject sampleProject({
  String id = 'p1',
  String name = 'ref.png',
  DrawingSettings settings = const DrawingSettings(),
  DateTime? updatedAt,
}) {
  final date = updatedAt ?? DateTime(2025, 1, 1, 10);
  return DrawingProject(
    id: id,
    originalName: name,
    imageFileName: 'image.png',
    thumbnailFileName: null,
    createdAt: date,
    updatedAt: date,
    settings: settings,
  );
}

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
