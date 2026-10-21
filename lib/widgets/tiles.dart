import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../routes.dart';
import 'common.dart';

/// One row in a list of models, datasets or Spaces.
class RepoTile extends StatelessWidget {
  const RepoTile({super.key, required this.repo, this.showOwner = true});
  final RepoSummary repo;
  final bool showOwner;

  String get _meta {
    final kind = switch (repo.type) {
      RepoType.model =>
        humanizeTag(repo.pipelineTag).isEmpty
            ? 'Model'
            : humanizeTag(repo.pipelineTag),
      RepoType.dataset => 'Dataset',
      RepoType.space =>
        repo.sdk == null ? 'Space' : '${humanizeTag(repo.sdk)} Space',
    };
    if (repo.type == RepoType.space || repo.downloads == 0) return kind;
    return '$kind · ${compactNumber(repo.downloads)} downloads';
  }

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => context.push(repoPath(repo.type, repo.id)),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: HugoColors.surfaceHigh)),
      ),
      child: Row(
        children: [
          OwnerAvatar(name: repo.owner.isEmpty ? repo.id : repo.owner),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showOwner && repo.owner.isNotEmpty)
                  Text(
                    repo.owner,
                    style: kMono.copyWith(
                      fontSize: 12,
                      color: HugoColors.textMuted,
                    ),
                  ),
                Text(
                  repo.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (repo.isPrivate) ...[
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 12,
                        color: HugoColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        _meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: HugoColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (repo.likes > 0) ...[
            const Icon(
              Icons.favorite_border_rounded,
              size: 14,
              color: HugoColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              compactNumber(repo.likes),
              style: const TextStyle(
                fontSize: 12,
                color: HugoColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class UpvoteBadge extends StatelessWidget {
  const UpvoteBadge(this.count, {super.key, this.vertical = false});
  final int count;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final children = [
      const Icon(Icons.arrow_upward_rounded, size: 14, color: HugoColors.amber),
      SizedBox(width: vertical ? 0 : 3, height: vertical ? 2 : 0),
      Text(
        '$count',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: HugoColors.amber,
        ),
      ),
    ];
    return Container(
      width: vertical ? 46 : null,
      padding: EdgeInsets.symmetric(
        horizontal: vertical ? 0 : 8,
        vertical: vertical ? 8 : 3,
      ),
      decoration: BoxDecoration(
        color: HugoColors.amberSoft,
        borderRadius: BorderRadius.circular(vertical ? 10 : 999),
      ),
      child: vertical
          ? Column(mainAxisSize: MainAxisSize.min, children: children)
          : Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// A paper in the Papers list.
class PaperCard extends StatelessWidget {
  const PaperCard({super.key, required this.paper});
  final Paper paper;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: HugoCard(
      padding: const EdgeInsets.all(12),
      onTap: () => context.push('/papers/${paper.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UpvoteBadge(paper.upvotes, vertical: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paper.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                if (paper.authorLine.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    paper.authorLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: HugoColors.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (paper.hasCode)
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.code_rounded,
                            size: 14,
                            color: HugoColors.blueText,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Code',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: HugoColors.blueText,
                            ),
                          ),
                        ],
                      ),
                    if (paper.numComments > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 13,
                            color: HugoColors.textMuted,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${paper.numComments}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: HugoColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    Text(
                      'arXiv ${paper.id}',
                      style: kMono.copyWith(
                        fontSize: 12,
                        color: HugoColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
