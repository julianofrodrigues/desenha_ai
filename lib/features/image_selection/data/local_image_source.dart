// Camada de "dados" da seleção de imagem.
//
// Por que separar isto da tela? A tela não deve saber QUAL pacote abre o
// seletor do sistema. Se um dia trocarmos o `file_picker` por outro pacote,
// só este arquivo muda. Também é o que permite testar a tela com uma fonte
// falsa, sem abrir a galeria de verdade.
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Imagem escolhida pelo usuário, já carregada na memória.
///
/// Guardamos os BYTES e não o caminho do arquivo porque, no Android moderno,
/// o seletor costuma devolver um endereço `content://` (do Storage Access
/// Framework), que não é um caminho de arquivo comum. Ler os bytes funciona
/// em qualquer caso, inclusive para imagens vindas de cartão SD.
class PickedImage {
  const PickedImage({required this.name, required this.bytes});

  /// Nome do arquivo (ex.: `gato.png`), mostrado na tela para o usuário
  /// confirmar que escolheu a imagem certa.
  final String name;

  /// Conteúdo bruto do arquivo (PNG, JPEG, WebP...).
  final Uint8List bytes;

  /// Tamanho em bytes. Usado só para exibição.
  int get sizeInBytes => bytes.lengthInBytes;
}

/// Contrato de "algo que fornece uma imagem local".
///
/// `abstract interface class` (Dart 3) diz: isto é só um contrato, quem usar
/// precisa implementar todos os métodos e não herda nenhum código.
abstract interface class LocalImageSource {
  /// Abre o seletor e devolve a imagem escolhida.
  ///
  /// Devolve `null` se o usuário cancelou. Cancelar NÃO é erro: é uma ação
  /// normal e a tela não deve mostrar mensagem vermelha por isso.
  ///
  /// Lança uma exceção se algo realmente deu errado (arquivo vazio,
  /// ilegível etc.).
  Future<PickedImage?> pickImage();
}

/// Implementação real, usando o pacote `file_picker`.
///
/// No Android, o `file_picker` abre o seletor NATIVO do sistema (Photo
/// Picker no Android 13+ ou o seletor de documentos nos mais antigos).
/// Vantagens para o nosso caso:
/// - funciona 100% offline: só lê arquivos que já estão no aparelho;
/// - não precisa pedir permissão de armazenamento, porque é o sistema que
///   mostra os arquivos e entrega ao app só o que o usuário escolheu.
class FilePickerImageSource implements LocalImageSource {
  @override
  Future<PickedImage?> pickImage() async {
    // `FileType.image` filtra para mostrar só imagens. Evita que o usuário
    // escolha um PDF por engano e caia numa tela de erro.
    final file = await FilePicker.pickFile(type: FileType.image);

    if (file == null) return null; // usuário cancelou

    final bytes = await file.readAsBytes();

    // Um arquivo de 0 bytes nunca é uma imagem válida. Melhor avisar aqui,
    // com uma mensagem clara, do que deixar o decodificador falhar depois.
    if (bytes.isEmpty) {
      throw const FormatException('O arquivo escolhido está vazio.');
    }

    return PickedImage(name: file.name, bytes: bytes);
  }
}
