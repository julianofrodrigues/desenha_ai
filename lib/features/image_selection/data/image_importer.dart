// Importação das imagens escolhidas na galeria para o histórico.
//
// Fica fora da `home_page.dart` por dois motivos: a tela já é grande (o
// steering pede ~300 linhas), e esta lógica não depende de widgets, então
// pode ter teste de unidade direto, sem montar a tela.
import 'package:flutter/foundation.dart';

import '../../projects/models/drawing_project.dart';
import '../../projects/services/project_repository.dart';
import 'local_image_source.dart';

/// O que aconteceu ao importar uma seleção da galeria.
@immutable
class ImportResult {
  const ImportResult({required this.created, required this.failedNames});

  /// Projetos criados, na ordem em que foram salvos.
  final List<DrawingProject> created;

  /// Nomes das imagens que não puderam ser salvas (vazias, ilegíveis, sem
  /// espaço no aparelho...).
  final List<String> failedNames;

  int get total => created.length + failedNames.length;

  /// Nenhuma imagem entrou no histórico.
  bool get allFailed => created.isEmpty;
}

/// Copia cada imagem para o armazenamento privado do app e cria um projeto
/// no histórico para ela.
///
/// - **Uma por vez**: lê os bytes de UMA imagem, salva (a cópia e a
///   miniatura ficam a cargo do repositório) e só então passa para a
///   próxima. Assim a memória guarda uma foto por vez, e não a seleção
///   inteira: com 20 fotos de câmera, a diferença é de ~5 MB contra
///   ~100 MB, o que decide se o Galaxy Tab A aguenta.
/// - **Uma falha não para as outras**: um arquivo vazio ou corrompido entra
///   em [ImportResult.failedNames] e o resto continua.
/// - [onProgress] recebe (posição atual, total) ANTES de cada imagem, para a
///   tela mostrar "Salvando imagem 2 de 5…".
Future<ImportResult> importPickedImages(
  List<PickedImage> images, {
  required ProjectRepository repository,
  void Function(int current, int total)? onProgress,
}) async {
  final created = <DrawingProject>[];
  final failed = <String>[];
  for (var i = 0; i < images.length; i++) {
    final image = images[i];
    onProgress?.call(i + 1, images.length);
    try {
      // `bytes` é local ao laço: ao fim de cada volta não há mais referência
      // a ele, e o coletor de lixo pode liberar a foto anterior.
      final bytes = await image.readBytes();
      created.add(
        await repository.create(originalName: image.name, imageBytes: bytes),
      );
    } catch (error) {
      debugPrint('Falha ao importar "${image.name}": $error');
      failed.add(image.name);
    }
  }
  return ImportResult(
    created: List.unmodifiable(created),
    failedNames: List.unmodifiable(failed),
  );
}

/// Mensagem curta (SnackBar) depois de uma importação com pelo menos uma
/// imagem salva.
String importSummary(ImportResult result) {
  final ok = result.created.length;
  final added = ok == 1
      ? '"${result.created.single.originalName}" foi adicionada ao histórico.'
      : '$ok imagens adicionadas ao histórico.';
  final failed = result.failedNames.length;
  if (failed == 0) return added;
  return failed == 1
      ? '$added 1 não pôde ser adicionada.'
      : '$added $failed não puderam ser adicionadas.';
}
