import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/app_scope.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../widgets/tiles.dart';

enum _PapersView { daily, trending, saved }

class PapersScreen extends StatefulWidget {
  const PapersScreen({super.key});

  @override
  State<PapersScreen> createState() => _PapersScreenState();
}

class _PapersScreenState extends State<PapersScreen> {
  _PapersView _view = _PapersView.daily;

  /// The UTC day being shown; null means the latest published day.
  DateTime? _date;

  /// The latest day the Hub has published, learned from the first load.
  DateTime? _latest;
  Future<List<Paper>>? _papers;
  bool _searching = false;
  final _search = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _papers ??= _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<Paper>> _load() {
    final api = context.api;
    final q = _search.text.trim();
    if (_searching && q.isNotEmpty) return api.searchPapers(q);
    return switch (_view) {
      _PapersView.daily => api.dailyPapers(_date).then((papers) {
        final day = papers.firstOrNull?.dailyDate?.toUtc();
        if (_date == null && day != null && mounted) {
          setState(() => _latest = DateTime.utc(day.year, day.month, day.day));
        }
        return papers;
      }),
      _PapersView.trending => api.trendingPapers(),
      _PapersView.saved => Future.value(const []),
    };
  }

  void _reload() => setState(() {
    _papers = _load();
  });

  DateTime get _shownDay {
    final d = _date ?? _latest;
    if (d != null) return d;
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month, now.day);
  }

  bool get _isLatest => _date == null;

  void _shiftDay(int days) {
    final next = _shownDay.add(Duration(days: days));
    _date = (_latest != null && !next.isBefore(_latest!)) ? null : next;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final showSearchResults = _searching && _search.text.trim().isNotEmpty;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: _searching
                  ? Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _search,
                            autofocus: true,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _reload(),
                            decoration: const InputDecoration(
                              hintText: 'Search papers',
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: HugoColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            _search.clear();
                            _searching = false;
                            _reload();
                          },
                          child: const Text('Cancel'),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Papers',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Search papers',
                          onPressed: () => setState(() => _searching = true),
                          icon: const Icon(Icons.search_rounded),
                        ),
                      ],
                    ),
            ),
            if (!showSearchResults) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<_PapersView>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: _PapersView.daily,
                      label: Text('Daily'),
                    ),
                    ButtonSegment(
                      value: _PapersView.trending,
                      label: Text('Trending'),
                    ),
                    ButtonSegment(
                      value: _PapersView.saved,
                      label: Text('Saved'),
                    ),
                  ],
                  selected: {_view},
                  onSelectionChanged: (s) {
                    _view = s.first;
                    _reload();
                  },
                ),
              ),
              if (_view == _PapersView.daily)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous day',
                        onPressed: () => _shiftDay(-1),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: Text(
                          dayLabel(_shownDay),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next day',
                        onPressed: _isLatest ? null : () => _shiftDay(1),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox(height: 12),
            ],
            Expanded(
              child: !showSearchResults && _view == _PapersView.saved
                  ? const _SavedList()
                  : RefreshIndicator(
                      onRefresh: () async {
                        _reload();
                        try {
                          await _papers;
                        } catch (_) {}
                      },
                      child: AsyncView<List<Paper>>(
                        future: _papers,
                        onRetry: _reload,
                        builder: (context, papers) {
                          if (papers.isEmpty) {
                            return ListView(
                              children: [
                                EmptyState(
                                  _view == _PapersView.daily &&
                                          !showSearchResults
                                      ? 'No papers for this day yet.'
                                      : 'No papers found.',
                                  icon: Icons.article_outlined,
                                ),
                              ],
                            );
                          }
                          return ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: papers.length,
                            itemBuilder: (_, i) => PaperCard(paper: papers[i]),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedList extends StatelessWidget {
  const _SavedList();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: context.settings,
    builder: (context, _) {
      final saved = context.settings.savedPapers;
      if (saved.isEmpty) {
        return const EmptyState(
          'Papers you save appear here. They stay on this device.',
          icon: Icons.bookmark_border_rounded,
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: saved.length,
        itemBuilder: (context, i) {
          final p = saved[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: HugoCard(
              onTap: () => context.push('/papers/${p['id']}'),
              child: Row(
                children: [
                  const Icon(
                    Icons.bookmark_rounded,
                    color: HugoColors.amber,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${p['title']}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'arXiv ${p['id']}',
                          style: kMono.copyWith(
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
        },
      );
    },
  );
}
