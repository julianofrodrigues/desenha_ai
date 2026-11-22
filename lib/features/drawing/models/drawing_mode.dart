/// O que aparece ATRÁS da imagem de referência.
enum DrawingMode {
  /// Câmera traseira ao vivo: o usuário aponta o aparelho para o papel.
  camera('Câmera AR'),

  /// Fundo sólido, sem câmera: o papel fica em cima da tela do tablet
  /// (como uma mesa de luz) ou o usuário quer economizar bateria.
  lightTable('Mesa de luz');

  const DrawingMode(this.label);

  /// Nome exibido para o usuário (ex.: no histórico da Home).
  final String label;
}

/// Cor do fundo no Modo Mesa de Luz.
///
/// Branco ilumina o papel por baixo (efeito mesa de luz de verdade). Preto
/// é melhor para ver a referência na tela sem papel e cansa menos a vista.
enum LightTableColor { white, black }

/// Converte o nome salvo em JSON de volta para o enum.
///
/// Salvamos `enum.name` (texto, ex.: "lightTable") e não o índice (0, 1):
/// se um dia a ordem dos valores mudar, arquivos antigos continuam corretos.
/// Um nome desconhecido vira [fallback] em vez de quebrar o carregamento.
T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}
