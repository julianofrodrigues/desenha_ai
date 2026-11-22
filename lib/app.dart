import 'package:material_ui/material_ui.dart';

import 'features/drawing/screens/drawing_screen.dart';
import 'features/drawing/services/screen_wake_lock.dart';
import 'features/image_selection/data/local_image_source.dart';
import 'features/image_selection/presentation/home_page.dart';
import 'features/projects/services/project_repository.dart';

/// Widget raiz do desenha_ai.
///
/// É um [StatelessWidget] porque não guarda nenhum dado que mude com o tempo:
/// só monta o [MaterialApp] com tema e tela inicial. O estado (histórico,
/// desenho atual) fica nas telas que precisam dele.
class DesenhaAiApp extends StatelessWidget {
  const DesenhaAiApp({
    super.key,
    required this.imageSource,
    required this.projectRepository,
    required this.cameraServiceFactory,
    required this.screenWakeLock,
  });

  /// De onde as imagens vêm. Recebido por parâmetro (injeção de dependência)
  /// para que testes possam passar uma implementação falsa.
  final LocalImageSource imageSource;

  /// Histórico de projetos no armazenamento interno.
  final ProjectRepository projectRepository;

  /// Cria o serviço de câmera usado pela tela de desenho.
  final CameraServiceFactory cameraServiceFactory;

  /// Mantém a tela ligada durante o desenho.
  final ScreenWakeLock screenWakeLock;

  @override
  Widget build(BuildContext context) {
    // Uma cor-semente gera a paleta inteira do Material 3 (botões, fundos,
    // textos) com contraste adequado. Assim não escolhemos dezenas de cores
    // à mão e o modo escuro sai "de graça".
    const seed = Colors.deepOrange;

    return MaterialApp(
      title: 'desenha_ai',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
      ),
      // Segue a configuração claro/escuro do aparelho. Útil para desenhar à
      // noite sem ser ofuscado pela tela do tablet.
      themeMode: ThemeMode.system,
      home: HomePage(
        imageSource: imageSource,
        projectRepository: projectRepository,
        cameraServiceFactory: cameraServiceFactory,
        screenWakeLock: screenWakeLock,
      ),
    );
  }
}
