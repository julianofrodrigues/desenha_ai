import '../models/project_category.dart';

/// Contrato das categorias do usuário (Fase 5, Etapa 5A).
///
/// Separado do `ProjectRepository` porque são dados diferentes: categorias
/// são uma lista pequena e global, e projetos são pastas com imagem. A tela
/// depende só desta interface; os testes usam uma versão em memória.
abstract interface class CategoryRepository {
  /// Todas as categorias, em ordem alfabética (ignorando maiúsculas e
  /// acentos), que é a ordem em que aparecem para escolher.
  Future<List<ProjectCategory>> listAll();

  /// Cria uma categoria. Lança [CategoryValidationException] se o nome for
  /// vazio, longo demais ou repetido.
  Future<ProjectCategory> create({
    required String name,
    required int colorValue,
  });

  /// Remove a categoria. NÃO mexe nos projetos: quem chama limpa o vínculo
  /// com `ProjectRepository.clearCategory` (ver docs/06).
  Future<void> delete(ProjectCategory category);

  /// Muda o nome e a cor de uma categoria existente (Etapa 6D). O `id` não
  /// muda, então os projetos vinculados passam a mostrar o nome e a cor
  /// novos SEM precisar regravar nenhum projeto.
  ///
  /// Lança [CategoryValidationException] se o nome for vazio, longo demais
  /// ou igual ao de OUTRA categoria, e [CategoryNotFoundException] se a
  /// categoria foi removida. Devolve a categoria atualizada.
  Future<ProjectCategory> update(
    ProjectCategory category, {
    required String name,
    required int colorValue,
  });
}
