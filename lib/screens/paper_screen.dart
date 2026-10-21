import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/app_scope.dart';
import '../data/models.dart';
import '../routes.dart';
import '../widgets/common.dart';
import '../widgets/repo_widgets.dart';
import '../widgets/tiles.dart';
import 'model_screen.dart';

class PaperScreen extends StatefulWidget {
  const PaperScreen({super.key, required this.id});
  final String id;

  @override
  State<PaperScreen> createState() => _PaperScreenState();
}

class _PaperScreenState extends State<PaperScreen> {
  Future<Paper>? _paper;
  bool _abstractOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _paper ??= context.api.paper(widget.id);
  }

  String get _webUrl => 'https://huggingface.co/papers/${widget.id}';

  @override
  Widget build(BuildContext context) {
    final settings = context.settings;
    return Scaffold(
      appBar: AppBar(
        leading: const BackOrHomeButton(),
        actions: [
          ShareButton(url: _webUrl),
          FutureBuilder<Paper>(
            future: _paper,
            builder: (context, snap) => ListenableBuilder(
              listenable: settings,
              builder: (context, _) {
                final saved = settings.isSaved(widget.id);
                return IconButton(
                  tooltip: saved ? 'Remove from saved' : 'Save for later',
                  onPressed: snap.data == null
                      ? null
                      : () => settings.toggleSaved(snap.data!),
                  icon: Icon(
                    saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: saved ? HugoColors.amber : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: AsyncView<Paper>(
        future: _paper,
        onRetry: () => setState(() {
          _paper = context.api.paper(widget.id);
        }),
        builder: (context, p) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                UpvoteBadge(p.upvotes),
                Text(
                  'arXiv ${p.id}',
                  style: kMono.copyWith(
                    fontSize: 12,
                    color: HugoColors.textMuted,
                  ),
                ),
                if (p.publishedAt != null)
                  Text(
                    '· ${shortDate(p.publishedAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: HugoColors.textMuted,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              p.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.3,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              p.authors.length > 3
                  ? '${p.authors.take(3).join(', ')} and ${p.authors.length - 3} others'
                  : p.authors.join(', '),
              style: const TextStyle(fontSize: 13, color: HugoColors.textMuted),
            ),
            if (p.aiSummary != null) ...[
              const SizedBox(height: 16),
              HugoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 15,
                          color: HugoColors.amber,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'AI SUMMARY',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: HugoColors.amber,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      p.aiSummary!,
                      style: const TextStyle(fontSize: 14, height: 1.55),
                    ),
                    if (p.aiKeywords.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final k in p.aiKeywords.take(6)) Pill(k),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Abstract',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              p.summary.trim(),
              maxLines: _abstractOpen ? null : 4,
              overflow: _abstractOpen ? null : TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                height: 1.55,
                color: HugoColors.textSecondary,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _abstractOpen = !_abstractOpen),
                child: Text(_abstractOpen ? 'Show less' : 'Read more'),
              ),
            ),
            if (p.hasCode || p.projectPage != null || p.linked.isNotEmpty) ...[
              const Text(
                'Code & resources',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (p.hasCode)
                _ResourceTile(
                  icon: Icons.code_rounded,
                  tone: PillTone.blue,
                  title: p.githubRepo!.replaceFirst(
                    RegExp(r'^https?://github\.com/'),
                    '',
                  ),
                  subtitle:
                      'GitHub${p.githubStars != null ? ' · ★ ${compactNumber(p.githubStars)}' : ''}',
                  onTap: () => openInApp(context, p.githubRepo!),
                ),
              if (p.projectPage != null && p.projectPage!.isNotEmpty)
                _ResourceTile(
                  icon: Icons.language_rounded,
                  tone: PillTone.neutral,
                  title: Uri.tryParse(p.projectPage!)?.host ?? p.projectPage!,
                  subtitle: 'Project page',
                  onTap: () => openInApp(context, p.projectPage!),
                ),
              for (final r in p.linked.take(8))
                _ResourceTile(
                  icon: switch (r.type) {
                    RepoType.model => Icons.view_in_ar_rounded,
                    RepoType.dataset => Icons.storage_rounded,
                    RepoType.space => Icons.rocket_launch_outlined,
                  },
                  tone: switch (r.type) {
                    RepoType.model => PillTone.amber,
                    RepoType.dataset => PillTone.green,
                    RepoType.space => PillTone.blue,
                  },
                  title: r.id,
                  subtitle: switch (r.type) {
                    RepoType.model =>
                      'Model${r.detail != null ? ' · ${humanizeTag(r.detail)}' : ''}',
                    RepoType.dataset => 'Dataset citing this paper',
                    RepoType.space => r.detail ?? 'Space',
                  },
                  onTap: () => context.push(repoPath(r.type, r.id)),
                ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: detailBottomBar(
        label: 'Read full paper',
        icon: Icons.menu_book_rounded,
        onPressed: () => _openPaper(context),
        secondary: FilledButton.tonalIcon(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
          onPressed: () => context.go('/chat?paper=${widget.id}'),
          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
          label: const Text('Ask AI'),
        ),
      ),
    );
  }

  Future<void> _openPaper(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Read PDF'),
              subtitle: const Text(
                'The original paper, with zoom',
                style: TextStyle(color: HugoColors.textMuted),
              ),
              onTap: () =>
                  Navigator.pop(context, 'https://arxiv.org/pdf/${widget.id}'),
            ),
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('Read as web page'),
              subtitle: const Text(
                'arXiv HTML · text reflows to fit your screen',
                style: TextStyle(color: HugoColors.textMuted),
              ),
              onTap: () =>
                  Navigator.pop(context, 'https://arxiv.org/html/${widget.id}'),
            ),
            ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: const Text('Discussion on Hugging Face'),
              onTap: () => Navigator.pop(context, _webUrl),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    String? title;
    try {
      title = (await _paper)?.title;
    } catch (_) {}
    if (context.mounted) await openInApp(context, choice, title: title);
  }
}

class _ResourceTile extends StatelessWidget {
  const _ResourceTile({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final PillTone tone;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      PillTone.blue => (HugoColors.blueSoft, HugoColors.blueText),
      PillTone.green => (HugoColors.greenSoft, HugoColors.green),
      PillTone.amber => (HugoColors.amberSoft, HugoColors.amber),
      PillTone.neutral => (HugoColors.surfaceHigh, HugoColors.textSecondary),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: HugoCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kMono.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: HugoColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
