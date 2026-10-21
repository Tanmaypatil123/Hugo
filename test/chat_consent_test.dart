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
import 'package:hugo_app/screens/chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late List<String> chatRequests;

  Future<SettingsController> pumpChat(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({'hf_token': 'hf_test'});
    chatRequests = [];
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/chat/completions')) {
        chatRequests.add(req.body);
        return http.Response('data: [DONE]\n\n', 200);
      }
      if (req.url.path.endsWith('/models')) {
        return http.Response(jsonEncode({'data': []}), 200);
      }
      if (req.url.path == '/api/whoami-v2') {
        return http.Response(jsonEncode({'name': 'tanmay'}), 200);
      }
      return http.Response('[]', 200);
    });
    final auth = AuthController();
    final settings = SettingsController();
    await settings.load();
    final api = HubApi(client: client, tokenProvider: () => auth.token);
    auth.attach(api);
    await auth.load();
    await tester.pumpWidget(
      AppScope(
        api: api,
        auth: auth,
        settings: settings,
        child: MaterialApp(theme: buildHugoTheme(), home: const ChatScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return settings;
  }

  // Lets the fake HTTP stream finish; the reply's typing animation means
  // pumpAndSettle would never settle while it streams.
  Future<void> flush(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await flush(tester);
  }

  testWidgets('Chat asks before sending and sends nothing on "Not now"', (
    tester,
  ) async {
    final settings = await pumpChat(tester);
    await send(tester, 'Hello');

    expect(find.text('Before you chat'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await flush(tester);

    expect(chatRequests, isEmpty);
    expect(settings.chatConsent, isFalse);
    expect(
      find.widgetWithText(TextField, 'Hello'),
      findsOneWidget,
      reason: 'the draft is kept',
    );
  });

  testWidgets('Agreeing saves consent and sends the message', (tester) async {
    final settings = await pumpChat(tester);
    await send(tester, 'Hello');
    await tester.tap(find.text('Agree and continue'));
    await flush(tester);

    expect(settings.chatConsent, isTrue);
    expect(chatRequests, hasLength(1));

    await send(tester, 'Again');
    expect(find.text('Before you chat'), findsNothing);
    expect(chatRequests, hasLength(2));
  });
}
