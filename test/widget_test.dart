import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikezu_ishi_map/screens/login_screen.dart';
import 'package:ikezu_ishi_map/screens/nickname_screen.dart';
import 'package:ikezu_ishi_map/services/app_state.dart';

void main() {
  group('ログイン画面', () {
    testWidgets('タイトル・説明・ボタンが表示される', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      expect(find.text('全国いけず石マップ'), findsOneWidget);
      expect(find.text('路上の いけず石 を記録・共有しよう'), findsOneWidget);
      expect(find.text('Googleでサインイン'), findsOneWidget);
    });

    testWidgets('背景色がダークブラウン', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFF3e2714));
    });
  });

  group('ニックネーム入力画面', () {
    testWidgets('入力フィールドと保存ボタンが表示される', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: NicknameScreen()));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('はじめる'), findsOneWidget);
    });

    testWidgets('ニックネームを入力できる', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: NicknameScreen()));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'テストユーザー');
      expect(find.text('テストユーザー'), findsOneWidget);
    });
  });

  group('ホーム画面ナビゲーション', () {
    testWidgets('BottomNavigationBarに3タブある', (tester) async {
      AppState.bottomNavIndex.value = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: AppState.bottomNavIndex.value,
            onTap: (i) => AppState.bottomNavIndex.value = i,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.map), label: '地図'),
              BottomNavigationBarItem(icon: Icon(Icons.list), label: '一覧'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'プロフィール'),
            ],
          ),
        ),
      ));

      expect(find.text('地図'), findsOneWidget);
      expect(find.text('一覧'), findsOneWidget);
      expect(find.text('プロフィール'), findsOneWidget);
    });

    testWidgets('タブタップでインデックスが変わる', (tester) async {
      AppState.bottomNavIndex.value = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: AppState.bottomNavIndex.value,
            onTap: (i) => AppState.bottomNavIndex.value = i,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.map), label: '地図'),
              BottomNavigationBarItem(icon: Icon(Icons.list), label: '一覧'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'プロフィール'),
            ],
          ),
        ),
      ));

      await tester.tap(find.text('一覧'));
      expect(AppState.bottomNavIndex.value, 1);

      await tester.tap(find.text('プロフィール'));
      expect(AppState.bottomNavIndex.value, 2);
    });
  });
}
