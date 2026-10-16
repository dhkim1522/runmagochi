import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/app/providers.dart';
import 'package:runmagochi/run/domain/run_engine.dart';
import 'package:runmagochi/run/ui/in_run_screen.dart';

import 'fakes.dart';

Future<FakeController> open(
  WidgetTester tester, {
  RunSnapshot? initial,
  String? error,
  Object? endError,
}) async {
  final controller = FakeController(
    initial: initial ?? snap(RunState.paused, distanceM: 2910),
    error: error,
    endError: endError,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [runControllerProvider.overrideWith(() => controller)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const InRunScreen()),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  testWidgets('러닝 중에는 거리와 페이스·시간·일시정지 버튼이 보인다', (tester) async {
    await open(
      tester,
      initial: snap(
        RunState.recording,
        distanceM: 2910,
        movingTime: const Duration(minutes: 18, seconds: 42),
        avg: 385,
        current: 370,
      ),
    );
    expect(find.text('2.91'), findsOneWidget);
    expect(find.text("6'25\""), findsOneWidget);
    expect(find.text("6'10\""), findsOneWidget);
    expect(find.text('18:42'), findsOneWidget);
    expect(find.text('일시정지'), findsOneWidget);
  });

  testWidgets('일시정지 버튼을 누르면 pause 가 불리고 일시정지 화면이 된다', (tester) async {
    final c = await open(
      tester,
      initial: snap(RunState.recording, distanceM: 1000),
    );
    await tester.tap(find.text('일시정지'));
    await tester.pump();
    expect(c.calls, ['pause']);
    expect(find.text('재개'), findsOneWidget);
    expect(find.textContaining('kcal'), findsOneWidget);
  });

  testWidgets('재개 버튼은 resume 을 부른다', (tester) async {
    final c = await open(tester);
    await tester.tap(find.text('재개'));
    await tester.pump();
    expect(c.calls, ['resume']);
    expect(find.text('일시정지'), findsOneWidget);
  });

  testWidgets('종료 버튼을 짧게 누르면 종료되지 않는다', (tester) async {
    final c = await open(tester);
    await tester.tap(find.text('종료'));
    await tester.pump(const Duration(seconds: 2));
    expect(c.calls, isEmpty);
    expect(find.byType(InRunScreen), findsOneWidget);
  });

  testWidgets('1.4초만 누르고 떼면 종료되지 않는다', (tester) async {
    final c = await open(tester);
    final g = await tester.startGesture(tester.getCenter(find.text('종료')));
    await tester.pump(); // 첫 프레임에서 타이머가 시작된다.
    await tester.pump(const Duration(milliseconds: 1400));
    await g.up();
    await tester.pump(const Duration(seconds: 2));
    expect(c.calls, isEmpty);
  });

  testWidgets('1.5초 길게 누르면 end 가 불리고 화면이 닫힌다', (tester) async {
    final c = await open(tester);
    final g = await tester.startGesture(tester.getCenter(find.text('종료')));
    await tester.pump(); // 첫 프레임에서 타이머가 시작된다.
    await tester.pump(const Duration(milliseconds: 1501));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    expect(c.calls, ['end']);
    expect(find.byType(InRunScreen), findsNothing);
  });

  testWidgets('lastError 가 있으면 배너로 보인다', (tester) async {
    await open(tester, error: '위치를 읽지 못했어요');
    expect(find.text('위치를 읽지 못했어요'), findsOneWidget);
  });

  testWidgets('end 가 실패하면 일시정지 화면에 남고 종료 버튼이 다시 동작한다', (tester) async {
    final c = await open(tester, endError: StateError('fail'));
    Future<void> hold() async {
      final g = await tester.startGesture(tester.getCenter(find.text('종료')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1501));
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();
    }

    await hold();
    expect(c.calls, ['end']);
    expect(find.byType(InRunScreen), findsOneWidget);
    expect(find.text('재개'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0);

    c.endError = null;
    await hold();
    expect(c.calls, ['end', 'end']);
    expect(find.byType(InRunScreen), findsNothing);
  });

  testWidgets('러닝 저장이 실패해 ended 면 재개 없이 종료만 남는다', (tester) async {
    final c = await open(
      tester,
      initial: snap(RunState.ended, distanceM: 2910),
    );
    expect(find.text('2.91'), findsOneWidget);
    expect(find.text('재개'), findsNothing);
    expect(find.widgetWithText(FilledButton, '일시정지'), findsNothing);

    final g = await tester.startGesture(tester.getCenter(find.text('종료')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1501));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    expect(c.calls, ['end']);
    expect(find.byType(InRunScreen), findsNothing);
  });
}
