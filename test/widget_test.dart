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
  testWidgets('Home shows trending repos and the bottom tabs', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final client = MockClient((req) async {
      final path = req.url.path;
      if (path == '/api/models') {
        return http.Response(
          jsonEncode([
            {
              'id': 'google/embeddinggemma-2',
              'likes': 2758,
              'downloads': 172474,
              'pipeline_tag': 'feature-extraction',
              'tags': [],
            },
            {
              'id': 'x/Model-Uncensored',
              'likes': 9,
              'downloads': 1,
              'tags': [],
            },
          ]),
          200,
        );
      }
      if (path == '/api/daily_papers') {
        return http.Response(
          jsonEncode([
            {
              'paper': {
                'id': '2610.26802',
                'title': 'Scaling PEFT for Brain Encoding',
                'upvotes': 231,
                'authors': [],
              },
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

    expect(find.text('Hugo'), findsOneWidget);
    expect(find.text('embeddinggemma-2'), findsOneWidget);
    expect(
      find.text('Model-Uncensored'),
      findsNothing,
      reason: 'hidden by the default content filter',
    );
    for (final tab in ['Home', 'Explore', 'Papers', 'Chat', 'Profile']) {
      expect(find.widgetWithText(NavigationDestination, tab), findsOneWidget);
    }
    expect(find.text('Scaling PEFT for Brain Encoding'), findsOneWidget);
  });
}
