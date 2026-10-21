import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../data/app_scope.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../widgets/tiles.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  RepoType _type = RepoType.model;
  Future<List<RepoSummary>>? _trending;
  Future<List<Paper>>? _papers;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _trending ??= _loadTrending();
    _papers ??= _loadPapers();
  }

  Future<List<RepoSummary>> _loadTrending() =>
      context.api.listRepos(_type, limit: 20);

  Future<List<Paper>> _loadPapers() async {
    final papers = await context.api.dailyPapers(null);
    return papers.take(6).toList();
  }

  Future<void> _refresh() async {
    setState(() {
      _trending = _loadTrending();
      _papers = _loadPapers();
    });
    try {
      await Future.wait<Object>([_trending!, _papers!]);
    } catch (_) {
      // Errors are shown by each section's AsyncView.
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.settings;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Row(
                children: [
                  const HugoLogo(),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Hugo',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: () => context.push('/settings'),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SearchButton(onTap: () => context.push('/search')),
              const SizedBox(height: 8),
              const SectionHeader('Trending this week'),
              ChoiceChips<RepoType>(
                values: RepoType.values,
                selected: _type,
                label: (t) => switch (t) {
                  RepoType.model => 'Models',
                  RepoType.dataset => 'Datasets',
                  RepoType.space => 'Spaces',
                },
                onSelected: (t) => setState(() {
                  _type = t;
                  _trending = _loadTrending();
                }),
              ),
              const SizedBox(height: 4),
              ListenableBuilder(
                listenable: settings,
                builder: (context, _) => AsyncView<List<RepoSummary>>(
                  future: _trending,
                  onRetry: () => setState(() {
                    _trending = _loadTrending();
                  }),
                  builder: (context, repos) {
                    final visible = settings.filter(repos).take(8).toList();
                    if (visible.isEmpty) {
                      return const EmptyState('Nothing trending right now.');
                    }
                    return Column(
                      children: [for (final r in visible) RepoTile(repo: r)],
                    );
                  },
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/search?type=${_type.name}'),
                  child: const Text('See all'),
                ),
              ),
              SectionHeader(
                'Today\'s papers',
                action: 'All papers',
                onAction: () => context.go('/papers'),
              ),
              const SizedBox(height: 6),
              AsyncView<List<Paper>>(
                future: _papers,
                onRetry: () => setState(() {
                  _papers = _loadPapers();
                }),
                builder: (context, papers) => SizedBox(
                  height: 170,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: papers.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, i) => _PaperTeaser(paper: papers[i]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Search the Hub',
    child: Material(
      color: HugoColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: HugoColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: const SizedBox(
          height: 48,
          child: Row(
            children: [
              SizedBox(width: 14),
              Icon(Icons.search_rounded, color: HugoColors.textMuted, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Search models, datasets, Spaces',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, color: HugoColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PaperTeaser extends StatelessWidget {
  const _PaperTeaser({required this.paper});
  final Paper paper;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 250,
    child: HugoCard(
      onTap: () => context.push('/papers/${paper.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UpvoteBadge(paper.upvotes),
              if (paper.hasCode) ...[
                const SizedBox(width: 6),
                const Pill(
                  'Code',
                  tone: PillTone.blue,
                  icon: Icons.code_rounded,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Text(
              paper.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
          Text(
            paper.authorLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: HugoColors.textMuted),
          ),
        ],
      ),
    ),
  );
}
