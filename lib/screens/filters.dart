import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/hub_api.dart';
import '../data/models.dart';

class TaskOption {
  const TaskOption(this.tag, this.label, this.icon);
  final String tag;
  final String label;
  final IconData icon;
}

class FilterOption {
  const FilterOption(this.tag, this.label);
  final String tag;
  final String label;
}

const kTasks = [
  TaskOption('text-generation', 'Text Generation', Icons.notes_rounded),
  TaskOption(
    'image-text-to-text',
    'Image-Text-to-Text',
    Icons.image_search_rounded,
  ),
  TaskOption('text-to-image', 'Text-to-Image', Icons.brush_rounded),
  TaskOption(
    'text-to-speech',
    'Text-to-Speech',
    Icons.record_voice_over_rounded,
  ),
  TaskOption(
    'automatic-speech-recognition',
    'Speech Recognition',
    Icons.mic_rounded,
  ),
  TaskOption(
    'feature-extraction',
    'Feature Extraction',
    Icons.scatter_plot_rounded,
  ),
  TaskOption('image-to-image', 'Image-to-Image', Icons.auto_fix_high_rounded),
  TaskOption('text-to-video', 'Text-to-Video', Icons.movie_rounded),
  TaskOption('translation', 'Translation', Icons.translate_rounded),
  TaskOption(
    'image-classification',
    'Image Classification',
    Icons.category_rounded,
  ),
];

// Library, language and license all use `filter=`: the Hub ignores
// `library=` and `language=`.
const kLibraries = [
  FilterOption('transformers', 'transformers'),
  FilterOption('gguf', 'GGUF'),
  FilterOption('mlx', 'MLX'),
  FilterOption('diffusers', 'diffusers'),
  FilterOption('sentence-transformers', 'sentence-transformers'),
  FilterOption('safetensors', 'safetensors'),
  FilterOption('onnx', 'ONNX'),
];

const kLicenses = [
  FilterOption('license:apache-2.0', 'apache-2.0'),
  FilterOption('license:mit', 'mit'),
  FilterOption('license:cc-by-4.0', 'cc-by-4.0'),
  FilterOption('license:llama3.1', 'llama3.1'),
  FilterOption('license:openrail', 'openrail'),
];

const kLanguages = [
  FilterOption('en', 'English'),
  FilterOption('hi', 'Hindi'),
  FilterOption('zh', 'Chinese'),
  FilterOption('es', 'Spanish'),
  FilterOption('fr', 'French'),
  FilterOption('de', 'German'),
  FilterOption('ja', 'Japanese'),
  FilterOption('ar', 'Arabic'),
  FilterOption('pt', 'Portuguese'),
  FilterOption('ru', 'Russian'),
  FilterOption('bn', 'Bengali'),
  FilterOption('mr', 'Marathi'),
  FilterOption('ta', 'Tamil'),
  FilterOption('vi', 'Vietnamese'),
];

String? labelForTag(String tag) {
  for (final t in kTasks) {
    if (t.tag == tag) return t.label;
  }
  for (final o in [...kLibraries, ...kLicenses, ...kLanguages]) {
    if (o.tag == tag) return o.label;
  }
  return null;
}

/// Everything the Search screen sends to the Hub.
class SearchFilters {
  const SearchFilters({
    this.type = RepoType.model,
    this.sort = SortOption.trending,
    this.task,
    this.libraries = const {},
    this.licenses = const {},
    this.language,
    this.withInference = false,
  });

  final RepoType type;
  final SortOption sort;
  final String? task;
  final Set<String> libraries;
  final Set<String> licenses;
  final String? language;
  final bool withInference;

  int get activeCount =>
      (task != null ? 1 : 0) +
      libraries.length +
      licenses.length +
      (language != null ? 1 : 0) +
      (withInference ? 1 : 0);

  List<String> get filterTags => [...libraries, ...licenses, ?language];

  SearchFilters copyWith({
    RepoType? type,
    SortOption? sort,
    String? Function()? task,
    Set<String>? libraries,
    Set<String>? licenses,
    String? Function()? language,
    bool? withInference,
  }) => SearchFilters(
    type: type ?? this.type,
    sort: sort ?? this.sort,
    task: task != null ? task() : this.task,
    libraries: libraries ?? this.libraries,
    licenses: licenses ?? this.licenses,
    language: language != null ? language() : this.language,
    withInference: withInference ?? this.withInference,
  );

  SearchFilters cleared() => SearchFilters(type: type);
}

/// Bottom sheet with sort and filter options. Returns the new filters.
Future<SearchFilters?> showFiltersSheet(
  BuildContext context,
  SearchFilters current,
) => showModalBottomSheet<SearchFilters>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _FiltersSheet(initial: current),
);

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({required this.initial});
  final SearchFilters initial;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late SearchFilters f = widget.initial;

  bool get _isModel => f.type == RepoType.model;

  @override
  Widget build(BuildContext context) {
    final sorts = SortOption.values
        .where((s) => !(f.type == RepoType.space && s == SortOption.downloads))
        .toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filters',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => f = f.cleared()),
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                _group('Sort by', [
                  for (final s in sorts)
                    _chip(
                      s.label,
                      f.sort == s,
                      () => setState(() => f = f.copyWith(sort: s)),
                    ),
                ]),
                if (_isModel) ...[
                  _group('Task', [
                    for (final t in kTasks)
                      _chip(
                        t.label,
                        f.task == t.tag,
                        () => setState(() {
                          f = f.copyWith(
                            task: () => f.task == t.tag ? null : t.tag,
                          );
                        }),
                      ),
                  ]),
                  _group('Library', [
                    for (final l in kLibraries)
                      _chip(
                        l.label,
                        f.libraries.contains(l.tag),
                        () => setState(() {
                          f = f.copyWith(
                            libraries: _toggle(f.libraries, l.tag),
                          );
                        }),
                      ),
                  ]),
                ],
                _group('License', [
                  for (final l in kLicenses)
                    _chip(
                      l.label,
                      f.licenses.contains(l.tag),
                      () => setState(() {
                        f = f.copyWith(licenses: _toggle(f.licenses, l.tag));
                      }),
                    ),
                ]),
                if (f.type != RepoType.space)
                  _group('Language', [
                    for (final l in kLanguages)
                      _chip(
                        l.label,
                        f.language == l.tag,
                        () => setState(() {
                          f = f.copyWith(
                            language: () => f.language == l.tag ? null : l.tag,
                          );
                        }),
                      ),
                  ]),
                if (_isModel)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: HugoColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: HugoColors.divider),
                    ),
                    child: SwitchListTile(
                      title: const Text('Has an inference provider'),
                      subtitle: const Text(
                        'Models you can try in Chat',
                        style: TextStyle(
                          color: HugoColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      value: f.withInference,
                      onChanged: (v) =>
                          setState(() => f = f.copyWith(withInference: v)),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: HugoColors.divider)),
              ),
              child: FilledButton(
                onPressed: () => Navigator.pop(context, f),
                child: const Text('Show results'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Set<String> _toggle(Set<String> s, String v) =>
      s.contains(v) ? ({...s}..remove(v)) : {...s, v};

  Widget _group(String title, List<Widget> chips) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: HugoColors.textMuted,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
      ],
    ),
  );

  Widget _chip(String label, bool selected, VoidCallback onTap) => FilterChip(
    label: Text(label),
    selected: selected,
    showCheckmark: false,
    side: BorderSide(color: selected ? HugoColors.amber : HugoColors.border),
    labelStyle: TextStyle(
      fontSize: 13,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      color: selected ? HugoColors.amber : HugoColors.textSecondary,
    ),
    onSelected: (_) => onTap(),
  );
}
