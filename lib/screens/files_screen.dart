import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../widgets/repo_widgets.dart';

class FilesScreen extends StatelessWidget {
  const FilesScreen({
    super.key,
    required this.type,
    required this.id,
    this.path = '',
  });
  final RepoType type;
  final String id;
  final String path;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const BackOrHomeButton(),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(path.isEmpty ? 'Files' : path.split('/').last),
          Text(
            id,
            style: kMono.copyWith(fontSize: 12, color: HugoColors.textMuted),
          ),
        ],
      ),
      actions: [ShareButton(url: '${type.webUrl(id)}/tree/main/$path')],
    ),
    body: FilesList(type: type, id: id, path: path, shrinkWrap: false),
  );
}
