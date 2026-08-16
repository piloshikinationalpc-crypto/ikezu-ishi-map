import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ikezu_ishi_map/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E: ログイン画面', () {
    testWidgets('アプリ起動時にログイン画面が表示される', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('全国いけず石マップ'), findsOneWidget);
      expect(find.text('路上の いけず石 を記録・共有しよう'), findsOneWidget);
      expect(find.text('Googleでサインイン'), findsOneWidget);
    });

    testWidgets('Googleサインインボタンがタップ可能', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final button = find.text('Googleでサインイン');
      expect(button, findsOneWidget);
      expect(tester.widget<ElevatedButton>(
        find.ancestor(of: button, matching: find.byType(ElevatedButton)),
      ).onPressed, isNotNull);
    });
  });
}
