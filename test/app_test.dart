import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/app.dart';
import 'package:runmagochi/avatar/app/providers.dart';
import 'package:runmagochi/run/app/providers.dart';

import 'run/ui/fakes.dart';

void main() {
  testWidgets('하단 탭 3개가 보인다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          runControllerProvider.overrideWith(FakeController.new),
          runRepositoryProvider.overrideWithValue(FakeRepo((0, 0))),
          growthServiceProvider.overrideWithValue(
            FakeGrowthService(growthState(weekDistanceM: 0)),
          ),
        ],
        child: const RunmagochiApp(),
      ),
    );
    await tester.pump();
    expect(find.text('러닝'), findsOneWidget);
    expect(find.text('기록'), findsOneWidget);
    expect(find.text('아바타'), findsOneWidget);
    expect(find.text('0.00km 달성'), findsOneWidget);
  });
}
