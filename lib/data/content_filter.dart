import 'models.dart';

/// Decides which repos to hide. Pure Dart so tools can reuse it.
///
/// The Hub can't exclude a tag server-side, so filtering happens on the
/// device, after results arrive.
bool allowedRepo(
  RepoSummary repo, {
  bool hideMature = true,
  bool hideUncensored = true,
}) {
  if (hideMature && repo.tags.contains('not-for-all-audiences')) return false;
  if (hideUncensored && _unfilteredPattern.hasMatch(repo.id)) return false;
  return true;
}

final _unfilteredPattern = RegExp(
  r'uncensored|abliterat|obliterat|heretic|defiance|nsfw|nude|porn|hentai|erotic|lewd',
  caseSensitive: false,
);
