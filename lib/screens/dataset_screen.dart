import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/app_scope.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../widgets/repo_widgets.dart';

class DatasetScreen extends StatefulWidget {
  const DatasetScreen({super.key, required this.id});
  final String id;

  @override
  State<DatasetScreen> createState() => _DatasetScreenState();
}

class _DatasetScreenState extends State<DatasetScreen> {
  Future<RepoDetail>? _repo;
  Future<int?>? _bytes;
  int _tab = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repo ??= context.api.repo(RepoType.dataset, widget.id);
    _bytes ??= context.api.datasetBytes(widget.id);
  }

  String? _tagValue(RepoDetail r, String prefix) => r.tags
      .where((t) => t.startsWith(prefix))
      .map((t) => t.substring(prefix.length))
      .firstOrNull;

  @override
  Widget build(BuildContext context) {
    final url = RepoType.dataset.webUrl(widget.id);
    return Scaffold(
      appBar: AppBar(
        leading: const BackOrHomeButton(),
        actions: [
          ShareButton(url: url),
          LikeButton(type: RepoType.dataset, id: widget.id),
        ],
      ),
      body: AsyncView<RepoDetail>(
        future: _repo,
        onRetry: () => setState(() {
          _repo = context.api.repo(RepoType.dataset, widget.id);
        }),
        builder: (context, repo) {
          final task = _tagValue(repo, 'task_categories:');
          final languages = repo.tags
              .where((t) => t.startsWith('language:'))
              .map((t) => t.substring(9))
              .take(3);
          final format = _tagValue(repo, 'format:');
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              OwnerLink(owner: repo.owner),
              Text(
                repo.name,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (task != null)
                    Pill(humanizeTag(task), tone: PillTone.amber),
                  for (final l in languages) Pill(l),
                  if (format != null) Pill(format),
                  if (repo.license != null)
                    Pill(repo.license!, tone: PillTone.green),
                  if (repo.gated)
                    const Pill(
                      'Gated',
                      tone: PillTone.amber,
                      icon: Icons.lock_outline_rounded,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              FutureBuilder<int?>(
                future: _bytes,
                builder: (context, snap) => Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    if (snap.data != null) _stat(fileSize(snap.data), ''),
                    _stat(compactNumber(repo.downloads), 'downloads'),
                    _stat(compactNumber(repo.likes), 'likes'),
                    if (repo.lastModified != null)
                      _stat(shortDate(repo.lastModified), ''),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              DetailTabs(
                labels: const ['Viewer', 'Dataset card', 'Files'],
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
              const SizedBox(height: 12),
              if (_tab == 0) _Viewer(id: repo.id),
              if (_tab == 1) RepoCard(type: RepoType.dataset, id: repo.id),
              if (_tab == 2) FilesList(type: RepoType.dataset, id: repo.id),
            ],
          );
        },
      ),
    );
  }

  Widget _stat(String value, String label) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: HugoColors.text,
          ),
        ),
        if (label.isNotEmpty) TextSpan(text: ' $label'),
      ],
    ),
    style: const TextStyle(fontSize: 13, color: HugoColors.textMuted),
  );
}

/// Scrollable preview of a dataset's rows via datasets-server.
class _Viewer extends StatefulWidget {
  const _Viewer({required this.id});
  final String id;

  @override
  State<_Viewer> createState() => _ViewerState();
}

class _ViewerState extends State<_Viewer> {
  Future<List<DatasetSplit>>? _splits;
  DatasetSplit? _split;
  Future<RowsPage>? _rows;
  int _offset = 0;
  static const _pageSize = 25;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _splits ??= context.api.datasetSplits(widget.id).then((s) {
      if (s.isNotEmpty && mounted) {
        setState(() {
          _split = s.first;
          _rows = _loadRows();
        });
      }
      return s;
    });
  }

  Future<RowsPage> _loadRows() => context.api.datasetRows(
    widget.id,
    _split!,
    offset: _offset,
    length: _pageSize,
  );

  void _go(int offset) => setState(() {
    _offset = offset;
    _rows = _loadRows();
  });

  @override
  Widget build(BuildContext context) => AsyncView<List<DatasetSplit>>(
    future: _splits,
    onRetry: () => setState(() {
      _splits = context.api.datasetSplits(widget.id);
    }),
    builder: (context, splits) {
      if (splits.isEmpty || _split == null) {
        return const EmptyState(
          'The viewer isn\'t available for this dataset.',
          icon: Icons.table_chart_outlined,
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<DatasetSplit>(
            initialValue: _split,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Split'),
            items: [
              for (final s in splits)
                DropdownMenuItem(value: s, child: Text(s.label)),
            ],
            onChanged: (s) {
              if (s == null) return;
              _split = s;
              _go(0);
            },
          ),
          const SizedBox(height: 12),
          AsyncView<RowsPage>(
            future: _rows,
            onRetry: () => _go(_offset),
            builder: (context, page) => _RowsTable(
              page: page,
              offset: _offset,
              pageSize: _pageSize,
              onPage: _go,
            ),
          ),
        ],
      );
    },
  );
}

class _RowsTable extends StatelessWidget {
  const _RowsTable({
    required this.page,
    required this.offset,
    required this.pageSize,
    required this.onPage,
  });
  final RowsPage page;
  final int offset;
  final int pageSize;
  final ValueChanged<int> onPage;

  static String cell(Object? v) {
    if (v == null) return 'null';
    if (v is String) return v;
    if (v is Map && v['src'] is String) return '[media]';
    return jsonEncode(v);
  }

  void _showRow(BuildContext context, Map<String, dynamic> row, int index) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder: (context, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(
                'Row ${offset + index}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              for (final c in page.columns) ...[
                Text(
                  c,
                  style: kMono.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: HugoColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  cell(row[c]),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: HugoColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cols = page.columns.take(3).toList();
    final end = (offset + page.rows.length).clamp(0, page.total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: HugoColors.divider),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                color: HugoColors.surface,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    for (final c in cols)
                      Expanded(
                        child: Text(
                          c,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: kMono.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: HugoColors.textMuted,
                          ),
                        ),
                      ),
                    const SizedBox(width: 20),
                  ],
                ),
              ),
              for (var i = 0; i < page.rows.length; i++)
                InkWell(
                  onTap: () => _showRow(context, page.rows[i], i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: HugoColors.surfaceHigh),
                      ),
                    ),
                    child: Row(
                      children: [
                        for (final c in cols)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                cell(page.rows[i][c]),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: HugoColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                '${page.columns.length} columns · rows ${compactNumber(offset + 1)}–${compactNumber(end)} of ${compactNumber(page.total)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: HugoColors.textMuted,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Previous rows',
              onPressed: offset == 0
                  ? null
                  : () => onPage((offset - pageSize).clamp(0, offset)),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              tooltip: 'Next rows',
              onPressed: end >= page.total
                  ? null
                  : () => onPage(offset + pageSize),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ],
    );
  }
}
