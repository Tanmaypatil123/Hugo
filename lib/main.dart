import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'data/app_scope.dart';
import 'data/auth.dart';
import 'data/hub_api.dart';
import 'data/settings.dart';
import 'routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = AuthController();
  final settings = SettingsController();
  final api = HubApi(tokenProvider: () => auth.token);
  auth.attach(api);
  await settings.load();
  // Profile refresh runs in the background so the app opens immediately.
  auth.load();
  runApp(HugoApp(api: api, auth: auth, settings: settings));
}

class HugoApp extends StatefulWidget {
  const HugoApp({
    super.key,
    required this.api,
    required this.auth,
    required this.settings,
  });
  final HubApi api;
  final AuthController auth;
  final SettingsController settings;

  @override
  State<HugoApp> createState() => _HugoAppState();
}

class _HugoAppState extends State<HugoApp> {
  late final GoRouter _router = buildRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
    api: widget.api,
    auth: widget.auth,
    settings: widget.settings,
    child: MaterialApp.router(
      title: 'Hugo',
      debugShowCheckedModeBanner: false,
      theme: buildHugoTheme(),
      darkTheme: buildHugoTheme(),
      themeMode: ThemeMode.dark,
      routerConfig: _router,
    ),
  );
}
