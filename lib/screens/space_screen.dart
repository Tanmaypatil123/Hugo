import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/app_scope.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../widgets/repo_widgets.dart';
import 'model_screen.dart';

class SpaceScreen extends StatefulWidget {
  const SpaceScreen({super.key, required this.id});
  final String id;

  @override
  State<SpaceScreen> createState() => _SpaceScreenState();
}

class _SpaceScreenState extends State<SpaceScreen> {
  Future<RepoDetail>? _repo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repo ??= context.api.repo(RepoType.space, widget.id);
  }

  (String, Color) _status(String? stage) => switch (stage) {
    'RUNNING' || 'RUNNING_BUILDING' => ('Running', HugoColors.green),
    'SLEEPING' || 'PAUSED' => ('Sleeping', HugoColors.textSecondary),
    'BUILDING' ||
    'APP_STARTING' ||
    'RUNNING_APP_STARTING' => ('Starting', HugoColors.amber),
    'RUNTIME_ERROR' ||
    'BUILD_ERROR' ||
    'CONFIG_ERROR' => ('Error', HugoColors.danger),
    null => ('Unknown', HugoColors.textMuted),
    _ => (humanizeTag(stage.toLowerCase()), HugoColors.textSecondary),
  };

  @override
  Widget build(BuildContext context) {
    final url = RepoType.space.webUrl(widget.id);
    return Scaffold(
      appBar: AppBar(
        leading: const BackOrHomeButton(),
        backgroundColor: tintFor(widget.id),
        actions: [
          ShareButton(url: url),
          LikeButton(type: RepoType.space, id: widget.id),
        ],
      ),
      body: AsyncView<RepoDetail>(
        future: _repo,
        onRetry: () => setState(() {
          _repo = context.api.repo(RepoType.space, widget.id);
        }),
        builder: (context, repo) {
          final (status, color) = _status(repo.spaceStage);
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                color: tintFor(widget.id),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: HugoColors.background,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 8, color: color),
                          const SizedBox(width: 6),
                          Text(
                            status,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      repo.spaceTitle ?? repo.name,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    if (repo.spaceDescription != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        repo.spaceDescription!,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: HugoColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    HugoCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          ListTile(
                            title: const Text(
                              'Owner',
                              style: TextStyle(color: HugoColors.textMuted),
                            ),
                            trailing: Text(
                              repo.owner,
                              style: kMono.copyWith(fontSize: 14),
                            ),
                            onTap: () => context.push('/${repo.owner}'),
                          ),
                          const Divider(),
                          ListTile(
                            title: const Text(
                              'SDK',
                              style: TextStyle(color: HugoColors.textMuted),
                            ),
                            trailing: Text(humanizeTag(repo.sdk ?? 'unknown')),
                          ),
                          const Divider(),
                          ListTile(
                            title: const Text(
                              'Likes',
                              style: TextStyle(color: HugoColors.textMuted),
                            ),
                            trailing: Text(compactNumber(repo.likes)),
                          ),
                          const Divider(),
                          ListTile(
                            title: const Text(
                              'Files',
                              style: TextStyle(color: HugoColors.textMuted),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () =>
                                context.push('/files/space/${repo.id}'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const HugoCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: HugoColors.blueText,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Spaces are web apps made by the community. Hugo opens them in the in-app browser. Sleeping Spaces can take a minute to wake up.',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: HugoColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    RepoCard(type: RepoType.space, id: repo.id),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: FutureBuilder<RepoDetail>(
        future: _repo,
        builder: (context, snap) {
          final repo = snap.data;
          if (repo == null) return const SizedBox.shrink();
          // Gradio apps honor ?__theme=dark, which matches Hugo's dark UI.
          final appUrl = repo.spaceHost != null && repo.sdk == 'gradio'
              ? '${repo.spaceHost}/?__theme=dark'
              : repo.spaceHost ?? url;
          return detailBottomBar(
            label: 'Open Space',
            icon: Icons.play_arrow_rounded,
            onPressed: () => openInApp(
              context,
              appUrl,
              title: repo.spaceTitle ?? repo.name,
              spaceId: repo.id,
            ),
          );
        },
      ),
    );
  }
}
