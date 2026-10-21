import 'package:flutter/widgets.dart';

import 'auth.dart';
import 'hub_api.dart';
import 'settings.dart';

/// Gives every screen access to the shared services.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.api,
    required this.auth,
    required this.settings,
    required super.child,
  });

  final HubApi api;
  final AuthController auth;
  final SettingsController settings;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      api != oldWidget.api ||
      auth != oldWidget.auth ||
      settings != oldWidget.settings;
}

extension AppScopeX on BuildContext {
  HubApi get api => AppScope.of(this).api;
  AuthController get auth => AppScope.of(this).auth;
  SettingsController get settings => AppScope.of(this).settings;
}
