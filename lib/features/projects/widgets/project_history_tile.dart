import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../models/drawing_project.dart';

/// Um item da seção "Continuar desenhando".
class ProjectHistoryTile extends StatelessWidget {
  const ProjectHistoryTile({
    super.key,
    required this.project,
    required this.thumbnail,
    required this.onOpen,
    required this.onDelete,
  });

  final DrawingProject project;
  final File? thumbnail;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

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
        title: Text(
          project.originalName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(subtitle),
        trailing: IconButton(
          tooltip: 'Excluir desenho',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
        onTap: onOpen,
      ),
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
