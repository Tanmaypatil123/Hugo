import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hugo_app/core/theme.dart';
import 'package:hugo_app/data/app_scope.dart';
import 'package:hugo_app/data/auth.dart';
import 'package:hugo_app/data/hub_api.dart';
import 'package:hugo_app/data/settings.dart';
import 'package:hugo_app/screens/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Completer<http.Response> whoami;

  Future<AuthController> pumpProfile(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({'hf_token': 'hf_test'});
    whoami = Completer();
    final client = MockClient((req) {
      if (req.url.path == '/api/whoami-v2') return whoami.future;
      return Future.value(http.Response('[]', 200));
    });
    final auth = AuthController();
    final settings = SettingsController();
    await settings.load();
    final api = HubApi(client: client, tokenProvider: () => auth.token);
    auth.attach(api);
    await tester.pumpWidget(
      AppScope(
        api: api,
        auth: auth,
        settings: settings,
        child: MaterialApp(
          theme: buildHugoTheme(),
          home: const ProfileScreen(),
        ),
      ),
    );
    unawaited(auth.load());
    await tester.pump();
    return auth;
  }

  testWidgets('Profile shows the user once whoami finishes after sign-in', (
    tester,
  ) async {
    await pumpProfile(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    whoami.complete(
      http.Response(jsonEncode({'name': 'tanmay', 'fullname': 'Tanmay'}), 200),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tanmay'), findsOneWidget);
    expect(find.text('tanmay'), findsOneWidget);
  });

  testWidgets('Profile shows an error with retry when whoami fails', (
    tester,
  ) async {
    await pumpProfile(tester);

    whoami.complete(http.Response('{"error":"Hub is down"}', 500));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Hub is down'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });
}
