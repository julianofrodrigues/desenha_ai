import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';

/// Onde a escolha manual de tema fica guardada (Fase 6, Etapa 6A).
///
/// Só existem DOIS valores salvos: claro ou escuro. "Nenhum valor salvo"
/// (`null`) significa "o usuário nunca escolheu", e aí o app segue o tema do
/// sistema.
abstract interface class ThemePreferenceStore {
  /// A escolha salva, ou `null` se o usuário nunca alternou o tema.
  Future<Brightness?> load();

  Future<void> save(Brightness brightness);
}

/// Preferência num JSON pequeno no armazenamento interno do app.
///
/// ```json
/// {"schemaVersion": 1, "theme": "dark"}
/// ```
///
/// Por que não o pacote `shared_preferences`? Para um único valor, um
/// arquivo resolve, com as MESMAS proteções do resto do app (gravação
/// atômica, tolerância a arquivo corrompido) e sem uma dependência nova.
class FileThemePreferenceStore implements ThemePreferenceStore {
  FileThemePreferenceStore({required this.file});

  /// No app: `<documentos do app>/preferences.json` (ver `main.dart`).
  final File file;

  static const int schemaVersion = 1;

  /// Toques rápidos no botão geram várias gravações. A fila garante que elas
  /// terminam NA ORDEM, ou seja, a última escolha é a que fica no disco.
  Future<void> _writes = Future.value();

  @override
  Future<Brightness?> load() async {
    try {
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, Object?>) return null;
      return switch (json['theme']) {
        'light' => Brightness.light,
        'dark' => Brightness.dark,
        // Valor desconhecido: como se nunca tivesse escolhido.
        _ => null,
      };
    } catch (error) {
      // Arquivo corrompido não pode impedir o app de abrir: volta a seguir
      // o tema do sistema.
      debugPrint('preferences.json ilegível: $error');
      return null;
    }
  }

  @override
  Future<void> save(Brightness brightness) {
    final result = _writes.then((_) => _write(brightness));
    _writes = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Gravação atômica: arquivo temporário + renomear (docs/04, 1.5).
  Future<void> _write(Brightness brightness) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode({'schemaVersion': schemaVersion, 'theme': brightness.name}),
      flush: true,
    );
    await temp.rename(file.path);
  }
}
