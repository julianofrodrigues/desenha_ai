// Ponto de entrada do app.
//
// Por que tão pequeno? O `main.dart` só deve "ligar" o app. Configuração de
// tema, rotas e telas ficam em outros arquivos, para que cada arquivo tenha
// uma responsabilidade só e seja fácil de achar quando o projeto crescer.
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'features/drawing/services/camera_service.dart';
import 'features/drawing/services/screen_wake_lock.dart';
import 'features/image_selection/data/local_image_source.dart';

void main() {
  // `runApp` recebe o widget raiz e o "infla" na tela.
  //
  // As implementações REAIS dos serviços são escolhidas só aqui e injetadas
  // no app. Nos testes, o app recebe versões falsas (sem galeria e sem
  // câmera de verdade), sem mudar nenhuma tela.
  runApp(
    DesenhaAiApp(
      imageSource: FilePickerImageSource(),
      // Uma FÁBRICA: cada abertura da tela de desenho cria um serviço novo,
      // e a tela o descarta ao fechar. Assim a câmera nunca fica ligada fora
      // da tela de desenho.
      cameraServiceFactory: PluginCameraService.new,
      screenWakeLock: const WakelockPlusScreenWakeLock(),
    ),
  );
}
