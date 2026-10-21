import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../data/app_scope.dart';
import '../data/hub_api.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../widgets/paged_list.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: context.auth,
    builder: (context, _) {
      final auth = context.auth;
      return Scaffold(
        appBar: AppBar(
          title: Text(auth.isSignedIn ? 'Profile' : ''),
          actions: [
            IconButton(
              tooltip: 'Settings',
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        body: auth.isSignedIn ? const _SignedIn() : const _SignIn(),
      );
    },
  );
}

class _SignIn extends StatefulWidget {
  const _SignIn();

  @override
  State<_SignIn> createState() => _SignInState();
}

class _SignInState extends State<_SignIn> {
  bool _busy = false;

  Future<void> _oauth() async {
    final auth = context.auth;
    if (!auth.oauthAvailable) {
      showMessage(
        context,
        'This build has no OAuth app yet. Use an access token for now.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await auth.signInWithOAuth();
    } on HubException catch (e) {
      if (mounted) showMessage(context, e.message);
    } catch (_) {
      if (mounted) showMessage(context, 'Sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
    children: [
      const Center(child: HugoLogo(size: 72)),
      const SizedBox(height: 16),
      const Text(
        'The Hub, in your pocket',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.2,
        ),
      ),
      const SizedBox(height: 10),
      const Text(
        'Sign in to see your repos, likes and private models, and to use Chat. Browsing works without an account.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          height: 1.5,
          color: HugoColors.textMuted,
        ),
      ),
      const SizedBox(height: 28),
      HuggingFaceSignInButton(onPressed: _oauth, busy: _busy),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => context.push('/token'),
        icon: const Icon(Icons.key_rounded, size: 18),
        label: const Text('Use an access token'),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => context.go('/'),
        child: const Text(
          'Continue as guest',
          style: TextStyle(color: HugoColors.textSecondary),
        ),
      ),
      const SizedBox(height: 20),
      const HugoCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.verified_user_outlined,
              color: HugoColors.green,
              size: 20,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Your token stays in this device\'s secure storage. Hugo has no server and only talks to huggingface.co.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: HugoColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'Hugo is an unofficial, open-source app and is not affiliated with Hugging Face.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          height: 1.5,
          color: HugoColors.textFaint,
        ),
      ),
    ],
  );
}

class _SignedIn extends StatefulWidget {
  const _SignedIn();

  @override
  State<_SignedIn> createState() => _SignedInState();
}

enum _MyView { models, datasets, spaces, likes }

class _SignedInState extends State<_SignedIn> {
  _MyView _view = _MyView.models;

  Future<RepoPage> _loadPage(String user, String? next) async {
    final api = context.api;
    final type = switch (_view) {
      _MyView.models => RepoType.model,
      _MyView.datasets => RepoType.dataset,
      _MyView.spaces => RepoType.space,
      _MyView.likes => null,
    };
    if (type == null) return RepoPage(items: await api.likes(user));
    return api.listReposPage(
      type,
      author: user,
      sort: SortOption.updated,
      limit: 30,
      nextUrl: next,
    );
  }

  // Listens to auth itself: the parent builds `const _SignedIn()`, which
  // Flutter won't rebuild when the profile arrives after the token.
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: context.auth,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final auth = context.auth;
    final me = auth.user;
    if (me == null) {
      final error = auth.profileError;
      if (error == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ErrorState(error: error, onRetry: auth.refreshProfile),
          TextButton(
            onPressed: auth.signOut,
            child: const Text(
              'Sign out',
              style: TextStyle(color: HugoColors.textSecondary),
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Row(
          children: [
            OwnerAvatar(name: me.name, url: me.avatarUrl, size: 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    me.fullname ?? me.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    me.name,
                    style: kMono.copyWith(
                      fontSize: 13,
                      color: HugoColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Public profile',
              onPressed: () => context.push('/${me.name}'),
              icon: const Icon(Icons.open_in_new_rounded),
            ),
          ],
        ),
        if (me.orgs.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final o in me.orgs)
                ActionChip(
                  label: Text(o),
                  onPressed: () => context.push('/$o'),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        ChoiceChips<_MyView>(
          values: _MyView.values,
          selected: _view,
          label: (v) => switch (v) {
            _MyView.models => 'My models',
            _MyView.datasets => 'Datasets',
            _MyView.spaces => 'Spaces',
            _MyView.likes => 'Liked',
          },
          onSelected: (v) => setState(() => _view = v),
        ),
        const SizedBox(height: 8),
        PagedRepoList(
          key: ValueKey('${me.name}/$_view'),
          loader: (next) => _loadPage(me.name, next),
          embedded: true,
          showOwner: _view == _MyView.likes,
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () async {
            await context.auth.signOut();
            if (context.mounted) {
              showMessage(
                context,
                'Signed out. Your token was deleted from this device.',
              );
            }
          },
          style: OutlinedButton.styleFrom(foregroundColor: HugoColors.danger),
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}
