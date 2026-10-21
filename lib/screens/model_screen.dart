import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/app_scope.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../widgets/repo_widgets.dart';

const _chatTasks = {'text-generation', 'image-text-to-text', 'conversational'};

class ModelScreen extends StatefulWidget {
  const ModelScreen({super.key, required this.id});
  final String id;

  @override
  State<ModelScreen> createState() => _ModelScreenState();
}

class _ModelScreenState extends State<ModelScreen> {
  Future<RepoDetail>? _repo;
  int _tab = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repo ??= context.api.repo(RepoType.model, widget.id);
  }

  @override
  Widget build(BuildContext context) {
    final url = RepoType.model.webUrl(widget.id);
    return Scaffold(
      appBar: AppBar(
        leading: const BackOrHomeButton(),
        actions: [
          ShareButton(url: url),
          LikeButton(type: RepoType.model, id: widget.id),
        ],
      ),
      body: AsyncView<RepoDetail>(
        future: _repo,
        onRetry: () => setState(() {
          _repo = context.api.repo(RepoType.model, widget.id);
        }),
        builder: (context, repo) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            _Header(repo: repo),
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (repo.pipelineTag != null)
                  Pill(humanizeTag(repo.pipelineTag), tone: PillTone.blue),
                if (repo.libraryName != null) Pill(repo.libraryName!),
                for (final t in repo.tags.where(
                  (t) => const {
                    'gguf',
                    'safetensors',
                    'mlx',
                    'onnx',
                    'fp8',
                    '8-bit',
                    '4-bit',
                  }.contains(t),
                ))
                  if (t != repo.libraryName) Pill(t),
                if (repo.license != null)
                  Pill(repo.license!, tone: PillTone.green),
                if (repo.gated)
                  const Pill(
                    'Gated',
                    tone: PillTone.amber,
                    icon: Icons.lock_outline_rounded,
                  ),
                if (repo.isPrivate)
                  const Pill('Private', icon: Icons.lock_outline_rounded),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    value: compactNumber(repo.downloads),
                    label: 'Downloads / mo',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(
                    value: compactNumber(repo.likes),
                    label: 'Likes',
                  ),
                ),
                if (repo.parameters != null && repo.parameters! > 0) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatTile(
                      value: paramCount(repo.parameters),
                      label: 'Parameters',
                    ),
                  ),
                ],
              ],
            ),
            if (repo.gated) ...[
              const SizedBox(height: 12),
              HugoCard(
                onTap: () => openInApp(context, url),
                child: const Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      color: HugoColors.amber,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This model is gated. Request access on huggingface.co to download its files.',
                        style: TextStyle(
                          fontSize: 13,
                          color: HugoColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 18,
                      color: HugoColors.textMuted,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            DetailTabs(
              labels: ['Model card', 'Files · ${repo.fileCount}', 'Community'],
              index: _tab,
              onChanged: (i) {
                if (i == 2) {
                  openInApp(context, '$url/discussions');
                } else {
                  setState(() => _tab = i);
                }
              },
            ),
            const SizedBox(height: 12),
            if (_tab == 0) RepoCard(type: RepoType.model, id: repo.id),
            if (_tab == 1) FilesList(type: RepoType.model, id: repo.id),
          ],
        ),
      ),
      bottomNavigationBar: FutureBuilder<RepoDetail>(
        future: _repo,
        builder: (context, snap) {
          final repo = snap.data;
          if (repo == null) return const SizedBox.shrink();
          final canChat = _chatTasks.contains(repo.pipelineTag);
          return _BottomActions(
            primaryLabel: canChat
                ? 'Chat with this model'
                : 'Open on huggingface.co',
            primaryIcon: canChat
                ? Icons.chat_bubble_outline_rounded
                : Icons.open_in_new_rounded,
            onPrimary: canChat
                ? () => context.go(
                    '/chat?model=${Uri.encodeQueryComponent(repo.id)}',
                  )
                : () => openInApp(context, url),
            secondary: canChat
                ? IconButton.filledTonal(
                    tooltip: 'Open on huggingface.co',
                    onPressed: () => openInApp(context, url),
                    icon: const Icon(Icons.open_in_new_rounded),
                  )
                : null,
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.repo});
  final RepoDetail repo;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      OwnerAvatar(name: repo.owner, size: 52),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OwnerLink(owner: repo.owner),
            Text(
              repo.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            if (repo.lastModified != null)
              Text(
                'Updated ${shortDate(repo.lastModified)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: HugoColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    this.secondary,
  });

  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback onPrimary;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: HugoColors.bar,
      border: Border(top: BorderSide(color: HugoColors.divider)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onPrimary,
                icon: Icon(primaryIcon),
                label: Text(primaryLabel),
              ),
            ),
            if (secondary != null) ...[const SizedBox(width: 10), secondary!],
          ],
        ),
      ),
    ),
  );
}

/// Exposed for other detail screens.
Widget detailBottomBar({
  required String label,
  required IconData icon,
  required VoidCallback onPressed,
  Widget? secondary,
}) => _BottomActions(
  primaryLabel: label,
  primaryIcon: icon,
  onPrimary: onPressed,
  secondary: secondary,
);
