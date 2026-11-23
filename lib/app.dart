import 'package:material_ui/material_ui.dart';

import 'features/drawing/screens/drawing_screen.dart';
import 'features/drawing/services/screen_wake_lock.dart';
import 'features/image_selection/data/local_image_source.dart';
import 'features/image_selection/presentation/home_page.dart';
import 'features/projects/services/category_repository.dart';
import 'features/projects/services/project_repository.dart';
import 'features/theme/app_theme.dart';
import 'features/theme/services/theme_controller.dart';

/// Widget raiz do desenha_ai.
///
/// É um [StatelessWidget] porque não guarda nenhum dado que mude com o tempo:
/// só monta o [MaterialApp] com tema e tela inicial. O estado (histórico,
/// desenho atual, tema) fica com quem é dono dele.
class DesenhaAiApp extends StatelessWidget {
  const DesenhaAiApp({
    super.key,
    required this.imageSource,
    required this.projectRepository,
    required this.categoryRepository,
    required this.cameraServiceFactory,
    required this.screenWakeLock,
    required this.themeController,
  });

  /// De onde as imagens vêm. Recebido por parâmetro (injeção de dependência)
  /// para que testes possam passar uma implementação falsa.
  final LocalImageSource imageSource;

  /// Histórico de projetos no armazenamento interno.
  final ProjectRepository projectRepository;

  /// Categorias do usuário no armazenamento interno (Fase 5).
  final CategoryRepository categoryRepository;

  /// Cria o serviço de câmera usado pela tela de desenho.
  final CameraServiceFactory cameraServiceFactory;

  /// Mantém a tela ligada durante o desenho.
  final ScreenWakeLock screenWakeLock;

  /// Modo claro/escuro escolhido (Fase 6). Criado e descartado pelo `main`.
  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    // A Home é montada UMA vez e passada como `child`: trocar o tema
    // reconstrói o `MaterialApp`, mas não cria uma Home nova (o estado dela,
    // como a busca e o filtro, continua intacto).
    final home = HomePage(
      imageSource: imageSource,
      projectRepository: projectRepository,
      categoryRepository: categoryRepository,
      cameraServiceFactory: cameraServiceFactory,
      screenWakeLock: screenWakeLock,
      themeController: themeController,
    );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController.mode,
      child: home,
      builder: (context, mode, home) => MaterialApp(
        title: 'desenha_ai',
        debugShowCheckedModeBanner: false,
        // Objetos criados uma vez (ver AppTheme): trocar o tema não recalcula
        // estilos.
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        // `system` (padrão, sem escolha salva) segue o aparelho; `light` e
        // `dark` são a escolha manual do usuário.
        themeMode: mode,
        // O `MaterialApp` já faz um "fade" suave entre os temas. 250 ms:
        // acompanha a animação do botão de sol/lua.
        themeAnimationDuration: const Duration(milliseconds: 250),
        home: home,
      ),
    );
  }
}
