import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:boardgamewar/main.dart';
import 'package:boardgamewar/providers/game_provider.dart';

void main() {
  testWidgets('시작 화면에 게임 시작 버튼이 표시된다', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => GameProvider())],
        child: const ARCardBattlerApp(),
      ),
    );

    // 시작 화면의 메인 액션 버튼 확인
    expect(find.text('게임 시작'), findsOneWidget);
  });

  testWidgets('게임 종료 버튼이 표시된다', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => GameProvider())],
        child: const ARCardBattlerApp(),
      ),
    );

    expect(find.text('게임 종료'), findsOneWidget);
  });
}
