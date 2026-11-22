/// O que aparece ATRÁS da imagem de referência.
enum DrawingMode {
  /// Câmera traseira ao vivo: o usuário aponta o aparelho para o papel.
  camera,

  /// Fundo sólido, sem câmera: o papel fica em cima da tela do tablet
  /// (como uma mesa de luz) ou o usuário quer economizar bateria.
  lightTable,
}

/// Cor do fundo no Modo Mesa de Luz.
///
/// Branco ilumina o papel por baixo (efeito mesa de luz de verdade). Preto
/// é melhor para ver a referência na tela sem papel e cansa menos a vista.
enum LightTableColor { white, black }
