import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hugo_app/data/auth.dart';
import 'package:hugo_app/data/hub_api.dart';
import 'package:hugo_app/data/settings.dart';
import 'package:hugo_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Papers tab: Daily, Trending and Saved', (tester) async {
    SharedPreferences.setMockInitialValues({
      'saved_papers': jsonEncode([
        {'id': '2610.24087', 'title': 'Saved OR-License'},
      ]),
    });
    final client = MockClient((req) async {
      final p = req.url.path;
      if (p == '/api/daily_papers') {
        return http.Response(
          jsonEncode([
            {
              'paper': {
                'id': '1',
                'title': 'Daily one',
                'upvotes': 3,
                'submittedOnDailyAt': '2026-10-20T00:00:00.000Z',
              },
            },
          ]),
          200,
        );
      }
      if (p == '/api/papers') {
        return http.Response(
          jsonEncode([
            {
              'id': '2',
              'title': 'Trending one',
              'upvotes': 7,
              'authors': [
                {'name': 'A'},
              ],
            },
          ]),
          200,
        );
      }
      return http.Response('[]', 200);
    });
    final auth = AuthController();
    final settings = SettingsController();
    await settings.load();
    final api = HubApi(client: client, tokenProvider: () => auth.token);
    auth.attach(api);
    await tester.pumpWidget(HugoApp(api: api, auth: auth, settings: settings));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'Papers'));
    await tester.pumpAndSettle();
    expect(find.text('Daily one'), findsOneWidget);

    await tester.tap(find.text('Trending'));
    await tester.pumpAndSettle();
    expect(find.text('Trending one'), findsOneWidget);

    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('Saved OR-License'), findsOneWidget);
  });
}
