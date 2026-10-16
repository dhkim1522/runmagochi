import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/app.dart';

void main() {
  testWidgets('하단 탭 3개가 보인다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: RunmagochiApp()));
    expect(find.text('러닝'), findsOneWidget);
    expect(find.text('기록'), findsOneWidget);
    expect(find.text('아바타'), findsOneWidget);
  });
}
