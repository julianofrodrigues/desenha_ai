import 'dart:io';
import 'dart:typed_data';

import '../models/drawing_project.dart';

/// Contrato do histórico de projetos.
///
/// A Home e a tela de desenho dependem só desta interface. A implementação
/// real grava em arquivos (`FileProjectRepository`); os testes de widget
/// usam uma versão em memória.
abstract interface class ProjectRepository {
  /// Copia a imagem para o armazenamento interno do app, gera a miniatura e
  /// grava o projeto com os ajustes padrão.
  Future<DrawingProject> create({
    required String originalName,
    required Uint8List imageBytes,
  });

  /// Projetos salvos, do acesso mais recente para o mais antigo.
  Future<List<DrawingProject>> listRecent();

  /// Lê a cópia da imagem. Lança [ProjectNotFoundException] se o projeto
  /// (ou a imagem dele) não existir mais.
  Future<Uint8List> readImage(DrawingProject project);

  /// Arquivo da miniatura, ou `null` se não houver.
  ///
  /// Devolvemos o `File` (e não os bytes) para a UI usar `Image.file`: o
  /// Flutter lê e decodifica o arquivo fora da thread da UI e guarda o
  /// resultado no cache de imagens.
  File? thumbnailFile(DrawingProject project);

  /// Grava os ajustes e atualiza o "último acesso". Devolve o projeto
  /// atualizado. Lança [ProjectNotFoundException] se o projeto foi excluído.
  Future<DrawingProject> save(DrawingProject project);

  /// Remove o projeto: registro, cópia da imagem e miniatura.
  Future<void> delete(DrawingProject project);
}

/// O projeto pedido não existe (foi excluído ou os arquivos sumiram).
class ProjectNotFoundException implements Exception {
  const ProjectNotFoundException(this.projectId);
  final String projectId;

  @override
  String toString() => 'ProjectNotFoundException($projectId)';
}
