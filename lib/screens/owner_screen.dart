import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/app_scope.dart';
import '../data/hub_api.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../widgets/repo_widgets.dart';
import '../widgets/paged_list.dart';

/// Profile of a user or organization, with their repos.
class OwnerScreen extends StatefulWidget {
  const OwnerScreen({super.key, required this.name});
  final String name;

  @override
  State<OwnerScreen> createState() => _OwnerScreenState();
}

class _OwnerScreenState extends State<OwnerScreen> {
  Future<OwnerOverview>? _owner;
  RepoType _type = RepoType.model;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _owner ??= context.api.owner(widget.name);
  }

  Future<RepoPage> _loadPage(String? next) => context.api.listReposPage(
    _type,
    author: widget.name,
    sort: _type == RepoType.space ? SortOption.likes : SortOption.downloads,
    limit: 30,
    nextUrl: next,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const BackOrHomeButton(),
      actions: [ShareButton(url: 'https://huggingface.co/${widget.name}')],
    ),
    body: AsyncView<OwnerOverview>(
      future: _owner,
      onRetry: () => setState(() {
        _owner = context.api.owner(widget.name);
      }),
      builder: (context, o) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Row(
            children: [
              OwnerAvatar(name: o.name, url: o.avatarUrl, size: 72),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            o.fullname ?? o.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (o.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            size: 20,
                            color: HugoColors.blue,
                            semanticLabel: 'Verified',
                          ),
                        ],
                        if (o.isPro) ...[
                          const SizedBox(width: 6),
                          const Pill('PRO', tone: PillTone.amber),
                        ],
                      ],
                    ),
                    Text(
                      '${o.name} · ${o.isOrg ? 'Organization' : 'User'}',
                      style: kMono.copyWith(
                        fontSize: 13,
                        color: HugoColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${compactNumber(o.followers)} followers${o.isOrg && o.members > 0 ? ' · ${o.members} members' : ''}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: HugoColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final (type, label, count) in [
                (RepoType.model, 'Models', o.models),
                (RepoType.dataset, 'Datasets', o.datasets),
                (RepoType.space, 'Spaces', o.spaces),
              ]) ...[
                Expanded(
                  child: _CountTab(
                    label: label,
                    count: count,
                    selected: _type == type,
                    onTap: () => setState(() => _type = type),
                  ),
                ),
                if (type != RepoType.space) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 8),
          PagedRepoList(
            key: ValueKey(_type),
            loader: _loadPage,
            embedded: true,
            showOwner: false,
          ),
        ],
      ),
    ),
  );
}

class _CountTab extends StatelessWidget {
  const _CountTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? HugoColors.amberSoft : HugoColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? HugoColors.amber : HugoColors.divider,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                compactNumber(count),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: selected ? HugoColors.amber : HugoColors.text,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? HugoColors.amber : HugoColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
