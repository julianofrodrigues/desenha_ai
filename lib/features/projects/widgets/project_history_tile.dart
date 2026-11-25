import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../models/drawing_project.dart';
import '../models/project_category.dart';
import '../models/project_status.dart';
import 'category_badge.dart';
import 'project_status_badge.dart';

/// Um item da seção "Continuar desenhando".
class ProjectHistoryTile extends StatelessWidget {
  const ProjectHistoryTile({
    super.key,
    required this.project,
    required this.thumbnail,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onChangeStatus,
    this.category,
  });

  final DrawingProject project;
  final File? thumbnail;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Abre a escolha de status (etapa final).
  final VoidCallback onChangeStatus;

  /// Categoria JÁ resolvida por quem monta a lista: `null` se o projeto não
  /// tem categoria ou se ela foi excluída. O card nunca procura categorias
  /// sozinho, então não há como mostrar uma categoria que não existe.
  final ProjectCategory? category;

  /// Lado da miniatura em dp. Toque confortável e pouca memória.
  static const double thumbnailSize = 64;

  @override
  Widget build(BuildContext context) {
    final subtitle = '${formatDateTime(project.updatedAt)} · '
        '${project.settings.mode.label}';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: _Thumbnail(file: thumbnail),
        // `displayName`: nome customizado > nome original > padrão (Fase 4).
        title: Text(
          project.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: _Subtitle(
          text: subtitle,
          status: project.status,
          category: category,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Etapa final: status à ESQUERDA do editar. Da esquerda para a
            // direita, as ações vão da mais leve (status) à destrutiva
            // (excluir), que continua na ponta.
            IconButton(
              tooltip: 'Alterar status',
              onPressed: onChangeStatus,
              icon: const Icon(Icons.flag_outlined),
            ),
            // Editar fica à ESQUERDA do excluir: a ação comum e reversível
            // vem primeiro, e a destrutiva fica na ponta, mais longe do
            // texto que o usuário está lendo.
            // Fase 5: o mesmo botão agora edita nome E categoria.
            IconButton(
              tooltip: 'Editar desenho',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Excluir desenho',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        onTap: onOpen,
      ),
    );
  }
}

/// Data · modo e, embaixo, as etiquetas: status (sempre) e categoria (se
/// houver), com o status À ESQUERDA.
///
/// `Wrap`: se as duas não couberem lado a lado (celular estreito, nomes
/// longos), a categoria desce para a linha de baixo em vez de dar overflow.
class _Subtitle extends StatelessWidget {
  const _Subtitle({
    required this.text,
    required this.status,
    required this.category,
  });

  final String text;
  final ProjectStatus status;
  final ProjectCategory? category;

  @override
  Widget build(BuildContext context) {
    final category = this.category;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            ProjectStatusBadge(status: status),
            if (category != null) CategoryBadge(category: category),
          ],
        ),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.file});

  final File? file;

  @override
  Widget build(BuildContext context) {
    const size = ProjectHistoryTile.thumbnailSize;
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.image_outlined),
    );
    final file = this.file;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: size,
        child: file == null
            ? placeholder
            : Image.file(
                file,
                fit: BoxFit.cover,
                // Decodifica no tamanho em que aparece (64 dp x densidade),
                // e não nos 256 px do arquivo. Com 20 itens na tela, a
                // diferença soma vários MB no cache de imagens do Tab A.
                cacheWidth:
                    (size * MediaQuery.devicePixelRatioOf(context)).round(),
                // Miniatura apagada ou corrompida: mostra o ícone em vez de
                // quebrar a lista.
                errorBuilder: (context, error, stackTrace) => placeholder,
              ),
      ),
    );
  }
}

/// `dd/MM/aaaa HH:mm` no horário local, sem depender do pacote `intl`.
String formatDateTime(DateTime dateTime) {
  final d = dateTime.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}
