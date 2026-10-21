import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/models.dart';
import 'screens/chat_screen.dart';
import 'screens/dataset_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/files_screen.dart';
import 'screens/home_screen.dart';
import 'screens/model_screen.dart';
import 'screens/owner_screen.dart';
import 'screens/paper_screen.dart';
import 'screens/papers_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/shell.dart';
import 'screens/space_screen.dart';
import 'screens/token_screen.dart';

/// App paths mirror huggingface.co URLs (`/{owner}/{name}`, `/datasets/...`,
/// `/spaces/...`, `/papers/{id}`), so shared Hub links open the right screen.
String repoPath(RepoType type, String id) => '/${type.urlPrefix}$id';

/// Turns a pasted huggingface.co (or hf.co) link into an in-app path.
String? pathFromHubUrl(String text) {
  final uri = Uri.tryParse(text.trim());
  if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
    return null;
  }
  if (uri.host != 'huggingface.co' &&
      uri.host != 'www.huggingface.co' &&
      uri.host != 'hf.co') {
    return null;
  }
  final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segs.isEmpty) return '/';
  if (segs.first == 'papers' && segs.length >= 2) return '/papers/${segs[1]}';
  if ((segs.first == 'datasets' || segs.first == 'spaces') &&
      segs.length >= 3) {
    return '/${segs[0]}/${segs[1]}/${segs[2]}';
  }
  if (segs.length >= 2) return '/${segs[0]}/${segs[1]}';
  return '/${segs[0]}';
}

final _rootKey = GlobalKey<NavigatorState>();

GoRouter buildRouter() => GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/',
  redirect: (context, state) {
    final p = state.uri.path;
    if (p == '/models' || p == '/datasets' || p == '/spaces') return '/explore';
    if (p == '/papers/trending' || p == '/papers/date') return '/papers';
    return null;
  },
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => HugoShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/explore', builder: (_, _) => const ExploreScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/papers', builder: (_, _) => const PapersScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/chat',
              builder: (_, state) => ChatScreen(
                initialModel: state.uri.queryParameters['model'],
                paperId: state.uri.queryParameters['paper'],
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/search',
      parentNavigatorKey: _rootKey,
      builder: (_, state) => SearchScreen(
        initialQuery: state.uri.queryParameters['q'] ?? '',
        initialType: RepoType.fromName(state.uri.queryParameters['type']),
        initialTask: state.uri.queryParameters['task'],
        initialFilter: state.uri.queryParameters['filter'],
      ),
    ),
    GoRoute(
      path: '/settings',
      parentNavigatorKey: _rootKey,
      builder: (_, _) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/token',
      parentNavigatorKey: _rootKey,
      builder: (_, _) => const TokenScreen(),
    ),
    GoRoute(
      path: '/files/:type/:owner/:name',
      parentNavigatorKey: _rootKey,
      builder: (_, s) => FilesScreen(
        type: RepoType.fromName(s.pathParameters['type']),
        id: '${s.pathParameters['owner']}/${s.pathParameters['name']}',
        path: s.uri.queryParameters['path'] ?? '',
      ),
    ),
    GoRoute(
      path: '/papers/:id',
      parentNavigatorKey: _rootKey,
      builder: (_, s) => PaperScreen(id: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/datasets/:owner/:name',
      parentNavigatorKey: _rootKey,
      builder: (_, s) => DatasetScreen(
        id: '${s.pathParameters['owner']}/${s.pathParameters['name']}',
      ),
    ),
    GoRoute(
      path: '/spaces/:owner/:name',
      parentNavigatorKey: _rootKey,
      builder: (_, s) => SpaceScreen(
        id: '${s.pathParameters['owner']}/${s.pathParameters['name']}',
      ),
    ),
    GoRoute(
      path: '/:owner',
      parentNavigatorKey: _rootKey,
      builder: (_, s) => OwnerScreen(name: s.pathParameters['owner']!),
      routes: [
        GoRoute(
          path: ':name',
          parentNavigatorKey: _rootKey,
          builder: (_, s) => ModelScreen(
            id: '${s.pathParameters['owner']}/${s.pathParameters['name']}',
          ),
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(),
    body: const Center(child: Text('This page isn\'t available in Hugo yet.')),
  ),
);
