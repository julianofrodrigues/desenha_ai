// Camada de "dados" da seleção de imagem.
//
// Por que separar isto da tela? A tela não deve saber QUAL pacote abre o
// seletor do sistema. Se um dia trocarmos o `file_picker` por outro pacote,
// só este arquivo muda. Também é o que permite testar a tela com uma fonte
// falsa, sem abrir a galeria de verdade.
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Imagem escolhida pelo usuário na galeria.
///
/// Desde a seleção múltipla, os bytes são lidos SOB DEMANDA ([readBytes]),
/// e não na hora da escolha. Motivo: o usuário pode escolher 20 fotos de
/// câmera de 5 MB cada. Ler todas de uma vez seriam ~100 MB na memória ao
/// mesmo tempo, o bastante para o Android fechar o app no Galaxy Tab A. A
/// Home lê UMA, salva no app e só então passa para a próxima.
///
/// Os bytes (e não o caminho) continuam sendo o formato final porque, no
/// Android moderno, o seletor costuma devolver um endereço `content://` (do
/// Storage Access Framework), que não é um caminho de arquivo comum. Ler os
/// bytes funciona em qualquer caso, inclusive para imagens do cartão SD.
class PickedImage {
  /// Imagem já na memória (usada pelos testes e por fontes simples).
  PickedImage({required this.name, required Uint8List bytes})
      : _read = (() async => bytes);

  /// Imagem lida só quando [readBytes] for chamado (a forma usada pelo
  /// seletor real, para não carregar todas as escolhidas de uma vez).
  ///
  /// `this._read` num parâmetro nomeado: quem chama escreve `read:` (o `_`
  /// some do nome), e o campo continua privado.
  PickedImage.lazy({required this.name, required this._read});

  /// Nome do arquivo (ex.: `gato.png`). Vira o nome original do projeto.
  final String name;

  final Future<Uint8List> Function() _read;

  /// Lê o conteúdo bruto do arquivo (PNG, JPEG, WebP...).
  ///
  /// Lança [FormatException] para um arquivo vazio: 0 bytes nunca é uma
  /// imagem válida, e é melhor avisar aqui, com uma mensagem clara, do que
  /// deixar o decodificador falhar depois.
  Future<Uint8List> readBytes() async {
    final bytes = await _read();
    if (bytes.isEmpty) {
      throw FormatException('O arquivo "$name" está vazio.');
    }
    return bytes;
  }
}

/// Contrato de "algo que fornece imagens locais".
///
/// `abstract interface class` (Dart 3) diz: isto é só um contrato, quem usar
/// precisa implementar todos os métodos e não herda nenhum código.
abstract interface class LocalImageSource {
  /// Abre o seletor e devolve as imagens escolhidas (uma ou várias).
  ///
  /// Devolve uma lista VAZIA se o usuário cancelou. Cancelar NÃO é erro: é
  /// uma ação normal e a tela não deve mostrar mensagem vermelha por isso.
  ///
  /// Lança uma exceção se o próprio seletor falhar. Problemas num arquivo
  /// específico (vazio, ilegível) só aparecem ao chamar
  /// [PickedImage.readBytes], para que uma imagem ruim não impeça as outras.
  Future<List<PickedImage>> pickImages();
}

/// Implementação real, usando o pacote `file_picker`.
///
/// No Android, o `file_picker` abre o seletor NATIVO do sistema (Photo
/// Picker no Android 13+ ou o seletor de documentos nos mais antigos), que
/// permite marcar várias imagens. Vantagens para o nosso caso:
/// - funciona 100% offline: só lê arquivos que já estão no aparelho;
/// - não precisa pedir permissão de armazenamento, porque é o sistema que
///   mostra os arquivos e entrega ao app só o que o usuário escolheu.
class FilePickerImageSource implements LocalImageSource {
  @override
  Future<List<PickedImage>> pickImages() async {
    // `pickFiles` (e não `pickFile`) permite escolher várias de uma vez.
    // `FileType.image` mostra só imagens: evita que o usuário escolha um PDF
    // por engano. Os arquivos chegam como referências; nada é lido aqui.
    final files = await FilePicker.pickFiles(type: FileType.image);
    return [
      for (final file in files)
        PickedImage.lazy(name: file.name, read: file.readAsBytes),
    ];
  }
}
