import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugo_app/core/theme.dart';
import 'package:hugo_app/widgets/common.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: buildHugoTheme(),
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('Hugging Face button shows the label and calls back', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      host(HuggingFaceSignInButton(onPressed: () => taps++)),
    );

    expect(find.text('Sign in with Hugging Face'), findsOneWidget);
    await tester.tap(find.byType(HuggingFaceSignInButton));
    expect(taps, 1);
  });

  testWidgets(
    'Hugging Face button shows a spinner and ignores taps while busy',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(HuggingFaceSignInButton(onPressed: () => taps++, busy: true)),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Sign in with Hugging Face'), findsNothing);
      await tester.tap(find.byType(HuggingFaceSignInButton));
      expect(taps, 0);
    },
  );
}
