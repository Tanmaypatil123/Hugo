import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/app_scope.dart';
import '../data/hub_api.dart';
import 'common.dart';
import 'tiles.dart';

/// Loads one page; `next` is null for the first page.
typedef RepoPageLoader = Future<RepoPage> Function(String? next);

/// A list of repos that loads the next page as you reach the end.
///
/// Give it a new [Key] to start over (e.g. when the search changes).
/// With [embedded] it renders as a Column with a "Load more" button, for use
/// inside another scroll view.
class PagedRepoList extends StatefulWidget {
  const PagedRepoList({
    super.key,
    required this.loader,
    this.showOwner = true,
    this.embedded = false,
    this.emptyMessage = 'Nothing here yet.',
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 24),
  });

  final RepoPageLoader loader;
  final bool showOwner;
  final bool embedded;
  final String emptyMessage;
  final EdgeInsetsGeometry padding;

  @override
  State<PagedRepoList> createState() => _PagedRepoListState();
}

class _PagedRepoListState extends State<PagedRepoList> {
  final List<RepoPage> _pages = [];
  String? _next;
  bool _loading = false;
  bool _started = false;
  Object? _error;

  bool get _hasMore => !_started || _next != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && !_loading) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.loader(_started ? _next : null);
      if (!mounted) return;
      setState(() {
        _pages.add(page);
        _next = page.next;
        _started = true;
        _loading = false;
      });
      _fillIfFiltered();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// The content filter can hide most of a page; keep loading until
  /// something useful is on screen.
  void _fillIfFiltered() {
    final visible = context.settings
        .filter(_pages.expand((p) => p.items).toList())
        .length;
    if (visible < 12 && _next != null && _pages.length < 6) _loadMore();
  }

  Widget _footer() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    if (_error != null) {
      final message = _error is HubException
          ? _error.toString()
          : 'Couldn\'t load more.';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  color: HugoColors.textSecondary,
                ),
              ),
            ),
            TextButton(onPressed: _loadMore, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (widget.embedded && _next != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: OutlinedButton(
          onPressed: _loadMore,
          child: const Text('Load more'),
        ),
      );
    }
    return const SizedBox(height: 8);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: context.settings,
    builder: (context, _) {
      final visible = context.settings.filter(
        _pages.expand((p) => p.items).toList(),
      );
      if (_started &&
          !_loading &&
          _error == null &&
          visible.isEmpty &&
          _next == null) {
        return EmptyState(widget.emptyMessage);
      }
      if (!_started && _error != null) {
        return ErrorState(error: _error!, onRetry: _loadMore);
      }
      Widget tile(int i) =>
          RepoTile(repo: visible[i], showOwner: widget.showOwner);

      if (widget.embedded) {
        return Column(
          children: [
            for (var i = 0; i < visible.length; i++) tile(i),
            _footer(),
          ],
        );
      }
      return NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 600) _loadMore();
          return false;
        },
        child: ListView.builder(
          padding: widget.padding,
          itemCount: visible.length + 1,
          itemBuilder: (_, i) => i == visible.length ? _footer() : tile(i),
        ),
      );
    },
  );
}
