import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../routes.dart';
import '../data/app_scope.dart';
import '../data/hub_api.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../widgets/paged_list.dart';
import 'filters.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    this.initialQuery = '',
    this.initialType = RepoType.model,
    this.initialTask,
    this.initialFilter,
  });

  final String initialQuery;
  final RepoType initialType;
  final String? initialTask;
  final String? initialFilter;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final _controller = TextEditingController(text: widget.initialQuery);
  late SearchFilters _filters;

  /// Bumped on every new search so the paged list starts over.
  int _generation = 0;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final f = widget.initialFilter;
    _filters = SearchFilters(
      type: widget.initialType,
      task: widget.initialTask,
      libraries: f != null && !f.startsWith('license:') ? {f} : const {},
      licenses: f != null && f.startsWith('license:') ? {f} : const {},
      sort: widget.initialQuery.isEmpty
          ? SortOption.trending
          : SortOption.downloads,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<RepoPage> _loadPage(String? next) => context.api.listReposPage(
    _filters.type,
    search: _controller.text.trim(),
    sort: _filters.sort,
    pipelineTag: _filters.task,
    filters: _filters.filterTags,
    withInferenceProvider: _filters.withInference,
    limit: 40,
    nextUrl: next,
  );

  void _reload() => setState(() => _generation++);

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _reload);
  }

  Future<void> _openFilters() async {
    final result = await showFiltersSheet(context, _filters);
    if (result != null) {
      _filters = result;
      _reload();
    }
  }

  List<(String, VoidCallback)> get _activeChips => [
    if (_filters.task != null)
      (
        labelForTag(_filters.task!) ?? _filters.task!,
        () => _filters = _filters.copyWith(task: () => null),
      ),
    for (final l in _filters.libraries)
      (
        labelForTag(l) ?? l,
        () => _filters = _filters.copyWith(
          libraries: {..._filters.libraries}..remove(l),
        ),
      ),
    for (final l in _filters.licenses)
      (
        labelForTag(l) ?? l,
        () => _filters = _filters.copyWith(
          licenses: {..._filters.licenses}..remove(l),
        ),
      ),
    if (_filters.language != null)
      (
        labelForTag(_filters.language!) ?? _filters.language!,
        () => _filters = _filters.copyWith(language: () => null),
      ),
    if (_filters.withInference)
      (
        'Inference available',
        () => _filters = _filters.copyWith(withInference: false),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final active = _filters.activeCount;
    return Scaffold(
      appBar: AppBar(
        leading: const BackOrHomeButton(),
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus:
              widget.initialQuery.isEmpty &&
              widget.initialTask == null &&
              widget.initialFilter == null,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (text) {
            final link = pathFromHubUrl(text);
            if (link != null) {
              context.push(link);
            } else {
              _reload();
            }
          },
          decoration: const InputDecoration(
            hintText: 'Search the Hub',
            prefixIcon: Icon(
              Icons.search_rounded,
              color: HugoColors.textMuted,
              size: 20,
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 10),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 12),
            child: Badge(
              isLabelVisible: active > 0,
              label: Text('$active'),
              backgroundColor: HugoColors.amber,
              textColor: HugoColors.onAmber,
              child: IconButton.filledTonal(
                tooltip: 'Filters and sort',
                onPressed: _openFilters,
                icon: const Icon(Icons.tune_rounded),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: ChoiceChips<RepoType>(
              values: RepoType.values,
              selected: _filters.type,
              label: (t) => switch (t) {
                RepoType.model => 'Models',
                RepoType.dataset => 'Datasets',
                RepoType.space => 'Spaces',
              },
              onSelected: (t) {
                _filters = _filters.copyWith(type: t);
                if (t == RepoType.space &&
                    _filters.sort == SortOption.downloads) {
                  _filters = _filters.copyWith(sort: SortOption.likes);
                }
                _reload();
              },
            ),
          ),
          if (_activeChips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (label, remove) in _activeChips)
                    InputChip(
                      label: Text(label),
                      onDeleted: () {
                        remove();
                        _reload();
                      },
                      deleteButtonTooltipMessage: 'Remove $label',
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Sorted by ${_filters.sort.label.toLowerCase()}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: HugoColors.textMuted,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _openFilters,
                  icon: const Icon(Icons.swap_vert_rounded, size: 18),
                  label: const Text('Sort'),
                ),
              ],
            ),
          ),
          Expanded(
            child: PagedRepoList(
              key: ValueKey(_generation),
              loader: _loadPage,
              emptyMessage: 'No results. Try another search or fewer filters.',
            ),
          ),
        ],
      ),
    );
  }
}
