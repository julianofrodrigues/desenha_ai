import 'package:flutter/foundation.dart';

import '../../drawing/models/drawing_settings.dart';

/// Um desenho salvo no histórico: a cópia da imagem + os ajustes da tela.
///
/// Os arquivos ficam numa pasta própria por projeto (ver
/// `FileProjectRepository`). Aqui guardamos só os NOMES dos arquivos,
/// relativos a essa pasta, e nunca caminhos absolutos. Por quê? O caminho
/// absoluto do armazenamento interno pode mudar (ex.: restauração de backup,
/// mudança de usuário do Android); o nome relativo continua válido.
@immutable
class DrawingProject {
  const DrawingProject({
    required this.id,
    required this.originalName,
    required this.imageFileName,
    required this.thumbnailFileName,
    required this.createdAt,
    required this.updatedAt,
    this.settings = const DrawingSettings(),
  });

  /// Versão do formato do `project.json`. Se o formato mudar no futuro,
  /// incrementamos e escrevemos a migração em [DrawingProject.fromJson].
  static const int schemaVersion = 1;

  /// Só letras minúsculas e números: vira nome de pasta (ver
  /// `FileProjectRepository`), então não pode ter `/` nem `..`.
  static final RegExp validId = RegExp(r'^[a-z0-9]+$');

  /// Nome de arquivo simples, sem pastas (`image.jpg`, `thumb.png`).
  static final RegExp validFileName = RegExp(r'^[A-Za-z0-9_-]+\.[A-Za-z0-9]{1,5}$');

  final String id;

  /// Nome do arquivo escolhido na galeria (ex.: `gato.jpg`), só para exibir.
  final String originalName;

  final String imageFileName;

  /// `null` se não foi possível gerar a miniatura (ex.: formato exótico).
  final String? thumbnailFileName;

  final DateTime createdAt;

  /// Último acesso: atualizado ao salvar E ao abrir. O histórico é ordenado
  /// por este campo.
  final DateTime updatedAt;

  final DrawingSettings settings;

  DrawingProject copyWith({DateTime? updatedAt, DrawingSettings? settings}) {
    return DrawingProject(
      id: id,
      originalName: originalName,
      imageFileName: imageFileName,
      thumbnailFileName: thumbnailFileName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      settings: settings ?? this.settings,
    );
  }

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'originalName': originalName,
        'imageFile': imageFileName,
        'thumbnailFile': thumbnailFileName,
        // ISO 8601 em UTC: texto legível, ordenável e sem ambiguidade de fuso
        // horário. Convertemos para o horário local só na hora de exibir.
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'settings': settings.toJson(),
      };

  /// Lê um `project.json`.
  ///
  /// Lança [FormatException] se faltar algo essencial (id, imagem, datas):
  /// sem isso o projeto não pode ser aberto, e o histórico simplesmente o
  /// ignora. Os AJUSTES, por outro lado, são tolerantes (ver
  /// [DrawingSettings.fromJson]): é melhor abrir com um ajuste padrão do que
  /// perder o desenho inteiro.
  factory DrawingProject.fromJson(Map<String, Object?> json) {
    final version = json['schemaVersion'];
    if (version is! int || version > schemaVersion) {
      // Arquivo de uma versão MAIS NOVA do app: não sabemos ler com
      // segurança.
      throw FormatException('schemaVersion não suportada: $version');
    }

    final id = json['id'];
    final imageFile = json['imageFile'];
    final thumbnailFile = json['thumbnailFile'];
    final settings = json['settings'];

    if (id is! String || !validId.hasMatch(id)) {
      throw FormatException('id inválido: $id');
    }
    // Validar nomes de arquivo impede que um JSON corrompido (ou adulterado)
    // aponte para arquivos fora da pasta do projeto (ex.: "../../x").
    if (imageFile is! String || !validFileName.hasMatch(imageFile)) {
      throw FormatException('imageFile inválido: $imageFile');
    }
    if (thumbnailFile != null &&
        (thumbnailFile is! String || !validFileName.hasMatch(thumbnailFile))) {
      throw FormatException('thumbnailFile inválido: $thumbnailFile');
    }

    final originalName = json['originalName'];
    return DrawingProject(
      id: id,
      originalName: originalName is String ? originalName : 'Imagem',
      imageFileName: imageFile,
      thumbnailFileName: thumbnailFile as String?,
      createdAt: _readDate(json['createdAt']),
      updatedAt: _readDate(json['updatedAt']),
      settings: settings is Map<String, Object?>
          ? DrawingSettings.fromJson(settings)
          : const DrawingSettings(),
    );
  }

  static DateTime _readDate(Object? value) {
    final date = value is String ? DateTime.tryParse(value) : null;
    if (date == null) throw FormatException('data inválida: $value');
    return date.toLocal();
  }

  @override
  bool operator ==(Object other) =>
      other is DrawingProject &&
      other.id == id &&
      other.originalName == originalName &&
      other.imageFileName == imageFileName &&
      other.thumbnailFileName == thumbnailFileName &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.settings == settings;

  @override
  int get hashCode => Object.hash(
        id,
        originalName,
        imageFileName,
        thumbnailFileName,
        createdAt,
        updatedAt,
        settings,
      );
}
