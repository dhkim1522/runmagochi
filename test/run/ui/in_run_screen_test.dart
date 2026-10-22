import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/app/providers.dart';
import 'package:runmagochi/avatar/domain/growth_rules.dart';
import 'package:runmagochi/avatar/ui/avatar_view.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/core/ui/components.dart';
import 'package:runmagochi/run/app/providers.dart';
import 'package:runmagochi/run/domain/run_engine.dart';
import 'package:runmagochi/run/domain/run_goal.dart';
import 'package:runmagochi/run/ui/in_run_screen.dart';

import 'fakes.dart';

Future<FakeController> open(
  WidgetTester tester, {
  RunSnapshot? initial,
  String? error,
  Object? endError,
  FakeGrowthService? growth,
  double? goalM,
  RunGoal? goal,
  bool goalReached = false,
}) async {
  final controller = FakeController(
    initial: initial ?? snap(RunState.paused, distanceM: 2910),
    error: error,
    endError: endError,
    initialGoalM: goalM,
    initialGoal: goal,
    initialGoalReached: goalReached,
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

  testWidgets('자동 일시정지면 멈춘 제목과 안내, 재개·일시정지·종료 버튼이 보인다', (tester) async {
    final c = await open(tester, initial: snap(RunState.autoPaused));
    expect(find.text('멈춰서 일시정지했어요'), findsOneWidget);
    expect(find.text('움직이면 이어져요'), findsOneWidget);
    expect(find.widgetWithText(AppButton, '일시정지'), findsOneWidget);
    expect(find.text('길게 눌러 종료'), findsOneWidget);
    await tester.tap(find.text('재개'));
    await tester.pump();
    expect(c.calls, ['resume']);
  });

  testWidgets('자동 일시정지에서 일시정지를 누르면 pause 가 불리고 사용자 일시정지가 된다', (tester) async {
    final c = await open(tester, initial: snap(RunState.autoPaused));
    await tester.tap(find.widgetWithText(AppButton, '일시정지'));
    await tester.pump();
    expect(c.calls, ['pause']);
    expect(find.text('멈춰서 일시정지했어요'), findsNothing);
    expect(find.widgetWithText(AppButton, '일시정지'), findsNothing);
    expect(find.text('재개'), findsOneWidget);
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
    expect(find.widgetWithText(AppButton, '일시정지'), findsNothing);

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
    for (final (state, dark) in [
      (RunState.recording, false),
      (RunState.paused, false),
      (RunState.autoPaused, false),
      (RunState.recording, true),
      (RunState.paused, true),
    ]) {
      for (final size in [const Size(390, 844), const Size(360, 640)]) {
        testWidgets(
          '$state ${size.width.toInt()}x${size.height.toInt()} ${dark ? '다크' : '라이트'} 에서 overflow 없이 그려진다',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final controller = FakeController(
              initialGoalM: 5000,
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
                  theme: dark ? appDarkTheme() : appLightTheme(),
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
            // 거리와 버튼은 화면 안에 다 보인다(러닝 중에는 스크롤하지 않는다).
            final screen = Offset.zero & size;
            final dist = tester.getRect(find.text('5.34'));
            expect(screen.contains(dist.topLeft), isTrue);
            expect(dist.right, lessThanOrEqualTo(size.width - Gap.s5 + 0.01));
            for (final b in find.byType(AppButton).evaluate()) {
              final r = tester.getRect(find.byWidget(b.widget));
              expect(r.bottom, lessThanOrEqualTo(size.height), reason: '$b');
            }
          },
        );
      }
    }
  });

  group('목표 진행', () {
    ProgressBar bar(WidgetTester tester) =>
        tester.widget<ProgressBar>(find.byType(ProgressBar));

    testWidgets('거리 아래에 목표와 진행 막대가 보인다', (tester) async {
      await open(
        tester,
        initial: snap(RunState.recording, distanceM: 2500),
        goalM: 5000,
      );
      expect(find.text('목표 5km'), findsOneWidget);
      expect(bar(tester).value, closeTo(0.5, 1e-9));
    });

    testWidgets('시간 목표면 목표 30분과 시간 진행 막대가 보인다', (tester) async {
      await open(
        tester,
        initial: snap(
          RunState.recording,
          distanceM: 2500,
          movingTime: const Duration(minutes: 15),
        ),
        goal: const TimeGoal(Duration(minutes: 30)),
      );
      expect(find.text('목표 30분'), findsOneWidget);
      expect(bar(tester).value, closeTo(0.5, 1e-9));
    });

    testWidgets('시간 목표 일시정지 화면에도 목표 줄이 보인다', (tester) async {
      await open(
        tester,
        initial: snap(RunState.paused, movingTime: const Duration(minutes: 6)),
        goal: const TimeGoal(Duration(minutes: 30)),
      );
      expect(find.text('목표 30분'), findsOneWidget);
      expect(bar(tester).value, closeTo(0.2, 1e-9));
    });

    testWidgets('시간 목표를 달성하면 목표 달성! 과 가득 찬 막대', (tester) async {
      final c = await open(
        tester,
        initial: snap(
          RunState.recording,
          movingTime: const Duration(minutes: 30, seconds: 2),
        ),
        goal: const TimeGoal(Duration(minutes: 30)),
      );
      expect(find.text('목표 달성!'), findsNothing);
      c.reachGoal();
      await settle(tester);
      expect(find.text('목표 달성!'), findsOneWidget);
      expect(bar(tester).value, 1);
    });

    testWidgets('목표가 없으면 목표 행이 없다', (tester) async {
      await open(tester, initial: snap(RunState.recording, distanceM: 2500));
      expect(find.byType(ProgressBar), findsNothing);
      expect(find.textContaining('목표'), findsNothing);
    });

    testWidgets('달성하면 목표 달성! 이 success 색이고 햅틱이 한 번 울린다', (tester) async {
      final haptics = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final c = await open(
        tester,
        initial: snap(RunState.recording, distanceM: 5010),
        goalM: 5000,
      );
      expect(haptics, isEmpty);
      expect(find.text('목표 달성!'), findsNothing);

      c.reachGoal();
      await settle(tester);
      expect(find.text('목표 달성!'), findsOneWidget);
      expect(find.text('목표 5km'), findsNothing);
      final style = tester
          .renderObject<RenderParagraph>(find.text('목표 달성!'))
          .text
          .style!;
      expect(style.color, AppColors.light.success);
      expect(bar(tester).value, 1);
      expect(haptics, hasLength(1));
    });

    testWidgets('이미 달성한 채로 열면 햅틱은 울리지 않는다', (tester) async {
      final haptics = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await open(
        tester,
        initial: snap(RunState.recording, distanceM: 5010),
        goalM: 5000,
        goalReached: true,
      );
      expect(find.text('목표 달성!'), findsOneWidget);
      expect(haptics, isEmpty);
    });
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

  group('시안 배치(작업 12)', () {
    // 실제 글자 폭으로 배치를 잰다(테스트 기본 글꼴은 모든 글자가 정사각형이다).
    setUpAll(() async {
      final font = File(
        'assets/fonts/RunmagochiSans.ttf',
      ).readAsBytesSync();
      await (FontLoader(
        'RunmagochiSans',
      )..addFont(Future.value(ByteData.sublistView(font)))).load();
    });

    /// 390×844 화면에 [state] 러닝 화면을 연다(목표 5km).
    Future<void> openAt(
      WidgetTester tester,
      RunState state, {
      Size size = const Size(390, 844),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await open(
        tester,
        initial: snap(
          state,
          distanceM: 3420,
          movingTime: const Duration(minutes: 21, seconds: 2),
          avg: 369,
          current: 362,
        ),
        goalM: 5000,
      );
    }

    Color? boxColor(WidgetTester tester, Finder of) {
      final box = tester.widget<DecoratedBox>(
        find.descendant(of: of, matching: find.byType(DecoratedBox)).first,
      );
      return (box.decoration as BoxDecoration).color;
    }

    testWidgets(
      '러닝 중: 제목 → 거리 128·km → 목표 줄·막대 → 지표 카드 하나 → 무대 6배 → 일시정지 어두운 판',
      (tester) async {
        await openAt(tester, RunState.recording);
        final c = AppColors.light;
        final title = tester.getRect(find.text('러닝 중'));
        final dist = tester.getRect(find.text('3.42'));
        final km = tester.getRect(find.text('km'));
        final goal = tester.getRect(find.text('목표 5km'));
        final bar = tester.getRect(find.byType(ProgressBar));
        final stats = tester.getRect(find.byType(StatsCard));
        final stage = tester.getRect(find.byType(PetStage));
        final pause = tester.getRect(find.byType(AppButton));
        expect(dist.top, greaterThan(title.bottom));
        // 거리는 줄이지 않은 128 이고 가운데, km 는 오른쪽에 같은 기준선으로.
        expect(dist.height, 128);
        expect((dist.left + km.right) / 2, closeTo(195, 1));
        expect(km.left, greaterThan(dist.right));
        expect(km.bottom, lessThanOrEqualTo(dist.bottom));
        final kmStyle = tester
            .renderObject<RenderParagraph>(find.text('km'))
            .text
            .style!;
        expect(kmStyle.color, c.inkMuted);
        // 목표 줄은 왼쪽 정렬, 막대는 전체 폭.
        expect(goal.top, greaterThan(dist.bottom));
        expect(goal.left, Gap.s5);
        expect(bar.top, greaterThan(goal.bottom));
        expect(bar.left, Gap.s5);
        expect(bar.right, 390 - Gap.s5);
        // 지표 3칸은 흰 카드 하나 안에.
        expect(stats.top, greaterThan(bar.bottom));
        expect(find.byType(AppCard), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(StatsCard),
            matching: find.byType(StatCard),
          ),
          findsNWidgets(3),
        );
        // 무대 위 6배 달리는 펫.
        expect(stage.top, greaterThan(stats.bottom));
        expect(stage.left, Gap.s5);
        expect(stage.right, 390 - Gap.s5);
        expect(tester.widget<PetStage>(find.byType(PetStage)).scale, 6);
        expect(tester.getSize(find.byType(AvatarView)), const Size(192, 192));
        expect(avatar(tester).action, AvatarAction.run);
        // 일시정지는 맨 아래 어두운 판 알약.
        expect(pause.top, greaterThan(stage.bottom));
        expect(boxColor(tester, find.byType(AppButton)), c.panel);
        expect(844 - pause.bottom, Gap.s8);
      },
    );

    testWidgets('거리 숫자가 다른 어떤 글자보다 크게 그려진다(화면에 그려진 높이)', (tester) async {
      await openAt(tester, RunState.recording);
      final distText = find.text('3.42');
      final dist = tester.getRect(distText).height;
      final others = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText() != '3.42',
      );
      expect(others, findsWidgets);
      for (final e in others.evaluate()) {
        final box = e.renderObject! as RenderBox;
        expect(box.size.height, lessThan(dist), reason: '${e.widget}');
      }
    });

    testWidgets('일시정지도 같은 체계: 거리 64 → 목표 → 지표 카드 → 무대 → 재개 → 길게 눌러 종료', (
      tester,
    ) async {
      await openAt(tester, RunState.paused);
      final dist = tester.getRect(find.text('3.42'));
      final goal = tester.getRect(find.text('목표 5km'));
      final stats = tester.getRect(find.byType(StatsCard));
      final stage = tester.getRect(find.byType(PetStage));
      final resume = tester.getRect(find.widgetWithText(AppButton, '재개'));
      final stop = tester.getRect(find.text('길게 눌러 종료'));
      // 일시정지는 number-l 64 로 줄여도 여전히 가장 큰 글자다.
      expect(
        tester
            .renderObject<RenderParagraph>(find.text('3.42'))
            .text
            .style!
            .fontSize,
        64,
      );
      expect(goal.top, greaterThan(dist.bottom));
      expect(stats.top, greaterThan(goal.bottom));
      expect(
        find.descendant(of: find.byType(StatsCard), matching: find.text('칼로리')),
        findsOneWidget,
      );
      expect(stage.top, greaterThan(stats.bottom));
      expect(resume.top, greaterThan(stage.bottom));
      expect(stop.top, greaterThan(resume.bottom));
      expect(tester.widget<PetStage>(find.byType(PetStage)).scale, 6);
      expect(avatar(tester).action, AvatarAction.idle);
      expect(
        boxColor(tester, find.widgetWithText(AppButton, '재개')),
        AppColors.light.panel,
      );
    });

    testWidgets('작은 화면(360×640)에서는 펫 배율을 줄여 무대에 맞춘다', (tester) async {
      await openAt(tester, RunState.recording, size: const Size(360, 640));
      expect(tester.takeException(), isNull);
      final stage = tester.getRect(find.byType(PetStage));
      final pet = tester.getRect(find.byType(AvatarView));
      expect(tester.widget<PetStage>(find.byType(PetStage)).scale, lessThan(6));
      expect(stage.top, lessThanOrEqualTo(pet.top));
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
