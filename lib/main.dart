// Ponto de entrada do app.
//
// Por que tão pequeno? O `main.dart` só deve "ligar" o app. Configuração de
// tema, rotas e telas ficam em outros arquivos, para que cada arquivo tenha
// uma responsabilidade só e seja fácil de achar quando o projeto crescer.
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'features/drawing/services/camera_service.dart';
import 'features/drawing/services/screen_wake_lock.dart';
import 'features/image_selection/data/local_image_source.dart';
import 'features/projects/services/file_category_repository.dart';
import 'features/projects/services/file_project_repository.dart';
import 'features/projects/services/thumbnail_generator.dart';

Future<void> main() async {
  // Necessário antes de usar plugins (como o path_provider) antes do
  // `runApp`: inicializa a ponte entre Dart e o código nativo.
  WidgetsFlutterBinding.ensureInitialized();

  // Pasta PRIVADA do app (no Android: /data/user/0/<pacote>/app_flutter).
  // Só este app lê e escreve nela, não precisa de permissão e ela é apagada
  // ao desinstalar. Resolvemos uma vez aqui (leva poucos ms) para que o
  // repositório saiba os caminhos de forma síncrona (ver docs/04).
  final documents = await getApplicationDocumentsDirectory();
  final projectsRoot =
      Directory('${documents.path}${Platform.pathSeparator}projects');

  // `runApp` recebe o widget raiz e o "infla" na tela.
  //
  // As implementações REAIS dos serviços são escolhidas só aqui e injetadas
  // no app. Nos testes, o app recebe versões falsas (sem galeria, câmera ou
  // disco de verdade), sem mudar nenhuma tela.
  runApp(
    DesenhaAiApp(
      imageSource: FilePickerImageSource(),
      projectRepository: FileProjectRepository(
        root: projectsRoot,
        thumbnails: const UiThumbnailGenerator(),
      ),
      // Fase 5: um arquivo só, AO LADO da pasta `projects/` (e não dentro
      // dela), para não ser confundido com a pasta de um projeto.
      categoryRepository: FileCategoryRepository(
        file: File(
          '${documents.path}${Platform.pathSeparator}categories.json',
        ),
      ),
      // Uma FÁBRICA: cada abertura da tela de desenho cria um serviço novo,
      // e a tela o descarta ao fechar. Assim a câmera nunca fica ligada fora
      // da tela de desenho.
      cameraServiceFactory: PluginCameraService.new,
      screenWakeLock: const WakelockPlusScreenWakeLock(),
    ),
  );
}
