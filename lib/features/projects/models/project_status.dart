/// Status de um desenho (etapa final), escolhido SÓ pelo usuário.
///
/// O app nunca muda o status sozinho: abrir, desenhar ou fechar a tela de
/// desenho não mexe nele. Só o botão de status do card (e o diálogo que ele
/// abre) altera este valor. Motivo: só o usuário sabe se terminou um
/// desenho ou se quer guardá-lo para depois. Um palpite automático ("abriu,
/// então está em andamento") erraria e o usuário teria de corrigir.
///
/// Este arquivo não importa nada do Flutter: o modelo fica fácil de testar.
/// Ícones e cores ficam em `widgets/project_status_style.dart`.
enum ProjectStatus {
  notStarted('notStarted', 'Não iniciado'),
  inProgress('inProgress', 'Em andamento'),
  done('done', 'Concluído'),
  archived('archived', 'Arquivado');

  const ProjectStatus(this.jsonValue, this.label);

  /// Texto gravado no `project.json`.
  ///
  /// Fixo e separado do nome do enum (`name`): se um dia renomearmos
  /// `done` para `finished` no código, os arquivos já salvos continuam
  /// sendo lidos.
  final String jsonValue;

  /// Nome mostrado na tela.
  final String label;

  /// Status de toda imagem nova e de todo projeto salvo antes desta etapa.
  static const ProjectStatus initial = notStarted;

  /// Lê o valor do JSON. Ausente (arquivo antigo), de outro tipo ou
  /// desconhecido (arquivo editado à mão) vira [initial]: um status estranho
  /// nunca impede abrir o desenho.
  static ProjectStatus fromJson(Object? value) {
    for (final status in values) {
      if (status.jsonValue == value) return status;
    }
    return initial;
  }
}
