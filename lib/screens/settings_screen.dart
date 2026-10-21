import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../data/app_scope.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.settings;
    final auth = context.auth;
    return Scaffold(
      appBar: AppBar(
        leading: const BackOrHomeButton(),
        title: const Text('Settings'),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([settings, auth]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const _Heading('Content'),
            _Group(
              children: [
                SwitchListTile(
                  title: const Text('Hide mature content'),
                  subtitle: const Text(
                    'Hides repos tagged not-for-all-audiences.',
                    style: TextStyle(color: HugoColors.textMuted, fontSize: 12),
                  ),
                  value: settings.hideMature,
                  onChanged: settings.setHideMature,
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Hide "uncensored" repos'),
                  subtitle: const Text(
                    'Also hides repos whose names suggest unfiltered models.',
                    style: TextStyle(color: HugoColors.textMuted, fontSize: 12),
                  ),
                  value: settings.hideUncensored,
                  onChanged: settings.setHideUncensored,
                ),
              ],
            ),
            const _Heading('Links & data'),
            _Group(
              children: [
                ListTile(
                  title: const Text('Open huggingface.co links in Hugo'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showLinksHelp(context),
                ),
                const Divider(),
                ListTile(
                  title: const Text('Clear image cache'),
                  onTap: () {
                    PaintingBinding.instance.imageCache
                      ..clear()
                      ..clearLiveImages();
                    showMessage(context, 'Image cache cleared.');
                  },
                ),
                if (auth.isSignedIn) ...[
                  const Divider(),
                  ListTile(
                    title: const Text(
                      'Sign out and delete token',
                      style: TextStyle(color: HugoColors.danger),
                    ),
                    onTap: () async {
                      await auth.signOut();
                      if (context.mounted) {
                        showMessage(
                          context,
                          'Your token was deleted from this device.',
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
            const _Heading('About'),
            _Group(
              children: [
                ListTile(
                  title: const Text('Source code on GitHub'),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () => openInApp(context, HugoConfig.repoUrl),
                ),
                const Divider(),
                ListTile(
                  title: const Text('Privacy policy'),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () => openInApp(context, HugoConfig.privacyPolicyUrl),
                ),
                const Divider(),
                ListTile(
                  title: const Text('Open-source licenses'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Hugo',
                    applicationVersion: HugoConfig.appVersion,
                    applicationIcon: const Padding(
                      padding: EdgeInsets.all(12),
                      child: HugoLogo(size: 56),
                    ),
                  ),
                ),
                const Divider(),
                ListTile(
                  title: const Text('Version'),
                  trailing: Text(
                    HugoConfig.appVersion,
                    style: kMono.copyWith(color: HugoColors.textMuted),
                  ),
                ),
              ],
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
        ),
      ),
    );
  }

  void _showLinksHelp(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Open links in Hugo'),
      content: const Text(
        'On Android, open your phone\'s Settings › Apps › Hugo › Open by default, '
        'then add huggingface.co. Links to models, datasets, Spaces and papers will then open here.\n\n'
        'On iPhone, copy a huggingface.co link and paste it into Hugo\'s search to open it here.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: HugoColors.textMuted,
        letterSpacing: 0.6,
      ),
    ),
  );
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => HugoCard(
    padding: EdgeInsets.zero,
    child: Column(children: children),
  );
}
