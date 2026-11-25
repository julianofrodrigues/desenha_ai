import 'package:flutter/foundation.dart';

import 'drawing_project.dart';
import 'project_status.dart';

/// Quais status aparecem no histórico (etapa final).
///
/// - Nada marcado ([none]) mostra TODOS, a mesma regra do filtro de
///   categorias. Na tela, é o chip "Todos" marcado (ver [showsAll]).
/// - Ao abrir o app, o filtro começa em [initial], que é o próprio [none]:
///   "Todos" marcado e a lista inteira à vista. O usuário vê de cara tudo o
///   que tem e só então restringe, em vez de achar que desenhos "sumiram"
///   por um filtro que ele não escolheu.
///
/// Imutável, com `==`: o `ValueNotifier` da Home só avisa a lista quando o
/// filtro muda de verdade (steering, seção 3).
@immutable
class StatusFilter {
  const StatusFilter(this.statuses);

  /// Nenhum status marcado = sem filtro de status ("Todos").
  static const none = StatusFilter(<ProjectStatus>{});

  /// O filtro com que a Home abre: "Todos" marcado.
  ///
  /// Um nome próprio (e não usar [none] direto na Home) deixa claro que é
  /// uma DECISÃO de produto. Para mudar o padrão no futuro, só esta linha
  /// muda.
  static const initial = none;

  final Set<ProjectStatus> statuses;

  bool get isActive => statuses.isNotEmpty;

  /// O chip "Todos" aparece marcado? Só quando NENHUM status específico está
  /// marcado.
  ///
  /// "Todos" não é um quinto valor guardado à parte: é só outra forma de
  /// mostrar o filtro vazio. Assim as regras saem sozinhas, sem estado para
  /// manter em sincronia:
  /// - marcar um status específico (via [toggle]) desmarca "Todos";
  /// - desmarcar o último específico marca "Todos";
  /// - tocar em "Todos" é voltar para [none], que desmarca os específicos.
  bool get showsAll => !isActive;

  bool isSelected(ProjectStatus status) => statuses.contains(status);

  StatusFilter toggle(ProjectStatus status) {
    final next = {...statuses};
    if (!next.remove(status)) next.add(status);
    return StatusFilter(Set.unmodifiable(next));
  }

  /// Garante que [status] apareça na lista, sem desmarcar nada.
  ///
  /// Usado depois de adicionar imagens: elas entram como "Não iniciado" e
  /// precisam ficar visíveis. Se já aparecem (status marcado ou filtro
  /// desligado), devolve a MESMA instância e o notifier não dispara.
  StatusFilter including(ProjectStatus status) {
    if (!isActive || isSelected(status)) return this;
    return StatusFilter(Set.unmodifiable({...statuses, status}));
  }

  /// O projeto passa no filtro?
  bool matches(DrawingProject project) =>
      !isActive || statuses.contains(project.status);

  @override
  bool operator ==(Object other) =>
      other is StatusFilter && setEquals(other.statuses, statuses);

  @override
  int get hashCode => Object.hashAllUnordered(statuses);

  @override
  String toString() => 'StatusFilter($statuses)';
}
