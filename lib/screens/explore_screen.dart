import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../data/app_scope.dart';
import '../data/models.dart';
import '../routes.dart';
import '../widgets/common.dart';
import '../widgets/tiles.dart';
import 'filters.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _controller = TextEditingController();
  Future<List<RepoSummary>>? _spaces;
  Future<List<RepoSummary>>? _datasets;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _spaces ??= context.api.listRepos(RepoType.space, limit: 12);
    _datasets ??= context.api.listRepos(RepoType.dataset, limit: 12);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String q) {
    final query = q.trim();
    final link = pathFromHubUrl(query);
    if (link != null) {
      context.push(link);
      return;
    }
    context.push('/search?q=${Uri.encodeQueryComponent(query)}');
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.settings;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const Text(
              'Explore',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: 'Search models, datasets, Spaces',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: HugoColors.textMuted,
                ),
                suffixIcon: IconButton(
                  tooltip: 'Filters',
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: () => context.push('/search'),
                ),
              ),
            ),
            const SectionHeader('Browse by task'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 3.2,
              children: [
                for (final t in kTasks.take(8))
                  HugoCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    onTap: () => context.push('/search?task=${t.tag}'),
                    child: Row(
                      children: [
                        Icon(t.icon, size: 20, color: HugoColors.amber),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            t.label,
                            maxLines: 2,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SectionHeader('Libraries'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final l in kLibraries)
                  ActionChip(
                    label: Text(
                      l.label,
                      style: kMono.copyWith(
                        fontSize: 13,
                        color: HugoColors.textSecondary,
                      ),
                    ),
                    onPressed: () => context.push('/search?filter=${l.tag}'),
                  ),
              ],
            ),
            SectionHeader(
              'Trending Spaces',
              action: 'See all',
              onAction: () => context.push('/search?type=space'),
            ),
            ListenableBuilder(
              listenable: settings,
              builder: (context, _) => AsyncView<List<RepoSummary>>(
                future: _spaces,
                onRetry: () => setState(() {
                  _spaces = context.api.listRepos(RepoType.space, limit: 12);
                }),
                builder: (context, list) => Column(
                  children: [
                    for (final r in settings.filter(list).take(4))
                      RepoTile(repo: r),
                  ],
                ),
              ),
            ),
            SectionHeader(
              'Trending datasets',
              action: 'See all',
              onAction: () => context.push('/search?type=dataset'),
            ),
            ListenableBuilder(
              listenable: settings,
              builder: (context, _) => AsyncView<List<RepoSummary>>(
                future: _datasets,
                onRetry: () => setState(() {
                  _datasets = context.api.listRepos(
                    RepoType.dataset,
                    limit: 12,
                  );
                }),
                builder: (context, list) => Column(
                  children: [
                    for (final r in settings.filter(list).take(4))
                      RepoTile(repo: r),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
