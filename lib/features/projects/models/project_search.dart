import 'drawing_project.dart';

/// Filtra o histórico pelo texto da barra de pesquisa (Fase 4).
///
/// Por que uma função pura, fora do widget?
/// - Dá para testar todas as regras sem montar nenhuma tela.
/// - A busca roda a cada tecla digitada; uma função simples sobre uma lista
///   de dezenas de itens leva microssegundos, mesmo no Galaxy Tab A. Não
///   precisamos de índice, banco de dados nem `debounce` aqui.
///
/// Regras:
/// - Busca no [DrawingProject.displayName], que já aplica a prioridade
///   nome customizado > nome original > nome padrão. Assim o que o usuário
///   VÊ é exatamente o que ele consegue pesquisar.
/// - Ignora maiúsculas/minúsculas e acentos: "passaro" encontra "Pássaro".
/// - Cada palavra digitada precisa aparecer no nome, em qualquer ordem:
///   "gato azul" encontra "Desenho azul do gato".
/// - Texto vazio (ou só espaços) devolve a lista inteira, na mesma ordem.
List<DrawingProject> filterProjects(
  List<DrawingProject> projects,
  String query,
) {
  final terms = normalizeForSearch(query)
      .split(' ')
      .where((term) => term.isNotEmpty)
      .toList();
  if (terms.isEmpty) return projects;

  return [
    for (final project in projects)
      if (_matchesAll(normalizeForSearch(project.displayName), terms)) project,
  ];
}

bool _matchesAll(String name, List<String> terms) =>
    terms.every(name.contains);

/// Minúsculas, sem acentos e com espaços simples.
///
/// Feito à mão (em vez de um pacote de "remover acentos") porque só
/// precisamos das letras do português e de algumas comuns em outras línguas
/// latinas. Uma dependência a mais não compensa.
String normalizeForSearch(String text) {
  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_withoutAccent[char] ?? char);
  }
  return buffer.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}

const _withoutAccent = <String, String>{
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', //
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n', 'ý': 'y', 'ÿ': 'y',
};
