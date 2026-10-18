import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/app/providers.dart';
import 'package:runmagochi/avatar/domain/growth_rules.dart';
import 'package:runmagochi/avatar/ui/avatar_view.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/core/ui/clay.dart';
import 'package:runmagochi/run/app/providers.dart';
import 'package:runmagochi/run/domain/run_engine.dart';
import 'package:runmagochi/run/ui/in_run_screen.dart';

import 'fakes.dart';

Future<FakeController> open(
  WidgetTester tester, {
  RunSnapshot? initial,
  String? error,
  Object? endError,
  FakeGrowthService? growth,
}) async {
  final controller = FakeController(
    initial: initial ?? snap(RunState.paused, distanceM: 2910),
    error: error,
    endError: endError,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        runControllerProvider.overrideWith(() => controller),
        growthServiceProvider.overrideWithValue(
          growth ?? FakeGrowthService(growthState()),
        ),
      ],
      child: MaterialApp(
        theme: appLightTheme(),
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
  await settle(tester);
  return controller;
}

/// 아바타 티커는 멈추지 않아 pumpAndSettle 이 끝나지 않는다. 고정 시간만 흘린다.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

AvatarView avatar(WidgetTester tester) =>
    tester.widget<AvatarView>(find.byType(AvatarView));

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
    expect(find.text('83'), findsOneWidget);
    expect(find.textContaining('kcal'), findsNothing);
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
    await tester.tap(find.text('길게 눌러 종료'));
    await tester.pump(const Duration(seconds: 2));
    expect(c.calls, isEmpty);
    expect(find.byType(InRunScreen), findsOneWidget);
  });

  testWidgets('1.4초만 누르고 떼면 종료되지 않는다', (tester) async {
    final c = await open(tester);
    final g = await tester.startGesture(
      tester.getCenter(find.text('길게 눌러 종료')),
    );
    await tester.pump(); // 첫 프레임에서 타이머가 시작된다.
    await tester.pump(const Duration(milliseconds: 1400));
    await g.up();
    await tester.pump(const Duration(seconds: 2));
    expect(c.calls, isEmpty);
  });

  testWidgets('1.5초 길게 누르면 end 가 불리고 화면이 닫힌다', (tester) async {
    final c = await open(tester);
    final g = await tester.startGesture(
      tester.getCenter(find.text('길게 눌러 종료')),
    );
    await tester.pump(); // 첫 프레임에서 타이머가 시작된다.
    await tester.pump(const Duration(milliseconds: 1501));
    await tester.pump();
    await g.up();
    await settle(tester);
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
      final g = await tester.startGesture(
        tester.getCenter(find.text('길게 눌러 종료')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1501));
      await tester.pump();
      await g.up();
      await settle(tester);
    }

    await hold();
    expect(c.calls, ['end']);
    expect(find.byType(InRunScreen), findsOneWidget);
    expect(find.text('재개'), findsOneWidget);
    final fill = tester.widget<FractionallySizedBox>(
      find.byKey(const Key('hold-fill')),
    );
    expect(fill.widthFactor, 0);

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
    expect(find.widgetWithText(ClayButton, '일시정지'), findsNothing);

    final g = await tester.startGesture(
      tester.getCenter(find.text('길게 눌러 종료')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1501));
    await tester.pump();
    await g.up();
    await settle(tester);
    expect(c.calls, ['end']);
    expect(find.byType(InRunScreen), findsNothing);
  });

  group('접근성', () {
    testWidgets('스크린 리더의 길게 누르기 동작으로 종료할 수 있다', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await open(tester);
      final node = tester.getSemantics(find.bySemanticsLabel('길게 눌러 종료'));
      expect(
        node.getSemanticsData().hasAction(ui.SemanticsAction.longPress),
        isTrue,
      );
      tester.semantics.longPress(find.semantics.byLabel('길게 눌러 종료'));
      await settle(tester);
      expect(c.calls, ['end']);
      handle.dispose();
    });

    testWidgets('종료 버튼은 시맨틱 노드가 하나이고 라벨이 중복되지 않는다', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester);
      expect(find.bySemanticsLabel('길게 눌러 종료'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('화면 제목은 헤더다', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester);
      expect(
        tester.getSemantics(find.widgetWithText(ScreenTitle, '일시정지')),
        matchesSemantics(label: '일시정지', isHeader: true),
      );
      handle.dispose();
    });
  });

  group('시안 요소', () {
    testWidgets('길게 눌러 종료 문구와 지표 카드 3개가 일시정지에 보인다', (tester) async {
      await open(tester);
      expect(find.text('일시정지'), findsOneWidget); // 제목
      expect(find.text('길게 눌러 종료'), findsOneWidget);
      expect(find.byType(StatCard), findsNWidgets(3));
      expect(find.text('칼로리'), findsOneWidget);
    });

    testWidgets('누르는 동안 종료 버튼이 왼쪽부터 차오른다', (tester) async {
      await open(tester);
      double factor() => tester
          .widget<FractionallySizedBox>(find.byKey(const Key('hold-fill')))
          .widthFactor!;
      expect(factor(), 0);
      final g = await tester.startGesture(
        tester.getCenter(find.text('길게 눌러 종료')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
      expect(factor(), closeTo(0.5, 0.05));
      await g.up();
      await tester.pump();
      expect(factor(), 0);
    });

    testWidgets('위치 오류 문구는 danger 색이다', (tester) async {
      await open(tester, error: '위치를 읽지 못했어요');
      final style = tester
          .renderObject<RenderParagraph>(find.text('위치를 읽지 못했어요'))
          .text
          .style!;
      expect(style.color, AppColors.light.danger);
    });
  });

  group('글자 크기 1.3배', () {
    for (final state in [RunState.recording, RunState.paused])
      for (final size in [const Size(390, 844), const Size(360, 640)]) {
        testWidgets(
          '$state ${size.width.toInt()}x${size.height.toInt()} 에서 overflow 없이 그려진다',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final controller = FakeController(
              initial: snap(
                state,
                distanceM: 5340,
                movingTime: const Duration(minutes: 32, seconds: 9),
                avg: 378,
                current: 370,
              ),
            );
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  runControllerProvider.overrideWith(() => controller),
                  growthServiceProvider.overrideWithValue(
                    FakeGrowthService(growthState()),
                  ),
                ],
                child: MaterialApp(
                  theme: appLightTheme(),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: const TextScaler.linear(1.3)),
                    child: child!,
                  ),
                  home: const InRunScreen(),
                ),
              ),
            );
            await settle(tester);
            expect(tester.takeException(), isNull);
          },
        );
      }
  });

  group('러닝 중 아바타', () {
    testWidgets('현재 페이스 300 이면 run, 표정은 기본', (tester) async {
      await open(tester, initial: snap(RunState.recording, current: 300));
      expect(avatar(tester).action, AvatarAction.run);
      expect(avatar(tester).mood, AvatarMood.normal);
      expect(avatar(tester).stage, 1);
    });

    testWidgets('현재 페이스 600 이면 walk', (tester) async {
      await open(tester, initial: snap(RunState.recording, current: 600));
      expect(avatar(tester).action, AvatarAction.walk);
    });

    testWidgets('현재 페이스가 없으면 walk', (tester) async {
      await open(tester, initial: snap(RunState.recording));
      expect(avatar(tester).action, AvatarAction.walk);
    });

    testWidgets('일시정지면 idle', (tester) async {
      await open(tester, initial: snap(RunState.paused, current: 300));
      expect(avatar(tester).action, AvatarAction.idle);
    });

    testWidgets('거리 숫자가 화면에서 가장 큰 글자다', (tester) async {
      await open(
        tester,
        initial: snap(
          RunState.recording,
          distanceM: 2910,
          avg: 385,
          current: 370,
        ),
      );
      double size(String t) => tester
          .renderObject<RenderParagraph>(find.text(t))
          .text
          .style!
          .fontSize!;
      final dist = size('2.91');
      expect(dist, greaterThan(size("6'25\"")));
      expect(dist, greaterThan(size("6'10\"")));
    });
  });

  testWidgets('종류를 읽기 전에는 병아리 대신 같은 크기의 빈 아바타 자리를 둔다', (tester) async {
    final g = FakeGrowthService(growthState(kind: AvatarKind.jelly))
      ..holdLoad = Completer<void>();
    await open(tester, growth: g);
    expect(find.byType(AvatarView), findsNothing);
    final before = tester.getRect(find.byType(AvatarSlot));

    g.holdLoad!.complete();
    await settle(tester);
    expect(find.byType(AvatarSlot), findsNothing);
    expect(avatar(tester).kind, AvatarKind.jelly);
    expect(tester.getRect(find.byType(AvatarView)), before);
  });
}
