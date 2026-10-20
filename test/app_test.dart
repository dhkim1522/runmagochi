import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/app.dart';
import 'package:runmagochi/avatar/app/providers.dart';
import 'package:runmagochi/avatar/domain/growth_rules.dart';
import 'package:runmagochi/core/korean.dart';
import 'package:runmagochi/onboarding/ui/onboarding_screen.dart';
import 'package:runmagochi/profile/app/providers.dart';
import 'package:runmagochi/run/app/permission_gate.dart';
import 'package:runmagochi/run/app/providers.dart';

import 'onboarding/onboarding_screen_test.dart' show FakeOnboardingGrowthRepo;
import 'run/ui/fakes.dart';

void main() {
  testWidgets('하단 탭 3개가 보인다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          runControllerProvider.overrideWith(FakeController.new),
          runRepositoryProvider.overrideWithValue(FakeRepo((0, 0))),
          profileRepositoryProvider.overrideWithValue(FakeProfile()),
          notificationSchedulerProvider.overrideWithValue(
            FakeNotificationScheduler(),
          ),
          growthServiceProvider.overrideWithValue(
            FakeGrowthService(growthState()),
          ),
        ],
        child: const RunmagochiApp(),
      ),
    );
    await tester.pump(); // 첫 실행 완료 여부
    await tester.pump(); // 홈의 성장 상태
    expect(find.text('러닝'), findsOneWidget);
    expect(find.text('기록'), findsOneWidget);
    expect(find.text('아바타'), findsOneWidget);
  });

  testWidgets('탭을 누르면 화면이 바뀌고 선택 상태가 시맨틱에 드러난다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          runControllerProvider.overrideWith(FakeController.new),
          runRepositoryProvider.overrideWithValue(FakeRepo((0, 0))),
          profileRepositoryProvider.overrideWithValue(FakeProfile()),
          notificationSchedulerProvider.overrideWithValue(
            FakeNotificationScheduler(),
          ),
          growthServiceProvider.overrideWithValue(
            FakeGrowthService(growthState()),
          ),
        ],
        child: const RunmagochiApp(),
      ),
    );
    await tester.pump();
    expect(
      tester.getSemantics(find.bySemanticsLabel('러닝')),
      matchesSemantics(
        label: '러닝',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
        hasEnabledState: false,
      ),
    );
    final box = tester.getSize(
      find
          .ancestor(of: find.text('기록'), matching: find.byType(ConstrainedBox))
          .first,
    );
    expect(box.height, greaterThanOrEqualTo(48));
    await tester.tap(find.text('기록'));
    await tester.pump();
    expect(find.text('최근 러닝'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('탭에 키보드 포커스가 가고 포커스 표시가 보이며 Enter·Space 로 바뀐다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          runControllerProvider.overrideWith(FakeController.new),
          runRepositoryProvider.overrideWithValue(FakeRepo((0, 0))),
          profileRepositoryProvider.overrideWithValue(FakeProfile()),
          notificationSchedulerProvider.overrideWithValue(
            FakeNotificationScheduler(),
          ),
          growthServiceProvider.overrideWithValue(
            FakeGrowthService(growthState()),
          ),
        ],
        child: const RunmagochiApp(),
      ),
    );
    await tester.pump();
    final ring = find.byKey(const ValueKey('tab-focus-ring'));
    expect(ring, findsNothing);

    // 탭 3개가 순서대로 포커스를 받는다.
    Future<void> tab() async {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }

    Size size(String t) => tester.getSize(
      find
          .ancestor(of: find.text(t), matching: find.byType(GestureDetector))
          .first,
    );
    final before = [
      for (final t in ['러닝', '기록', '아바타']) size(t),
    ];

    var found = false;
    for (var i = 0; i < 40 && !found; i++) {
      await tab();
      found = ring.evaluate().isNotEmpty;
    }
    expect(found, isTrue, reason: '탭 키로 하단 탭에 포커스가 간다');
    expect(ring, findsOneWidget);
    expect(
      [
        for (final t in ['러닝', '기록', '아바타']) size(t),
      ],
      before,
      reason: '포커스 표시가 탭 크기를 바꾸지 않는다',
    );

    // 포커스가 러닝 탭에 있다면 다음(기록)으로 옮겨 Enter.
    await tab();
    expect(
      find.descendant(of: ring, matching: find.text('기록')),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('최근 러닝'), findsOneWidget);

    await tab();
    expect(
      find.descendant(of: ring, matching: find.text('아바타')),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(find.text('최근 러닝'), findsNothing);
  });

  group('첫 실행', () {
    Widget app({
      FakeNotificationScheduler? scheduler,
      required FakeProfile profile,
      required FakeOnboardingGrowthRepo repo,
      required FakeGrowthService growth,
      required FakeController controller,
    }) => ProviderScope(
      key: UniqueKey(),
      overrides: [
        runControllerProvider.overrideWith(() => controller),
        runRepositoryProvider.overrideWithValue(FakeRepo((0, 0))),
        permissionGateProvider.overrideWithValue(FakeGate(GateResult.ready)),
        growthServiceProvider.overrideWithValue(growth),
        growthRepositoryProvider.overrideWithValue(repo),
        profileRepositoryProvider.overrideWithValue(profile),
        notificationSchedulerProvider.overrideWithValue(
          scheduler ?? FakeNotificationScheduler(),
        ),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 17)),
      ],
      child: const RunmagochiApp(),
    );

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('완료하지 않았으면 첫 실행 화면부터, 마치면 홈, 다시 켜면 바로 홈', (tester) async {
      final profile = FakeProfile(onboarded: false);
      final repo = FakeOnboardingGrowthRepo(kind: AvatarKind.acorn);
      final growth = FakeGrowthService(growthState());
      final controller = FakeController();
      await tester.pumpWidget(
        app(
          profile: profile,
          repo: repo,
          growth: growth,
          controller: controller,
        ),
      );
      // 읽는 동안에는 홈이 잠깐이라도 보이지 않는다.
      expect(find.text('러닝'), findsNothing);
      expect(find.byType(OnboardingScreen), findsNothing);
      await settle(tester);

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text(keepAll('꼬마 도토리가 왔어요!')), findsOneWidget);
      expect(find.text('러닝'), findsNothing);
      expect(controller.calls, isNot(contains('restore')), reason: '홈은 아직 없다');

      for (final label in ['다음', '시작하기']) {
        await tester.tap(find.text(label));
        await settle(tester);
      }
      expect(profile.marks, 1);
      expect(repo.names, ['토리']);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.text('러닝'), findsOneWidget);

      // 다시 켠다.
      await tester.pumpWidget(
        app(
          profile: profile,
          repo: repo,
          growth: growth,
          controller: FakeController(),
        ),
      );
      await tester.pump();
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.text('러닝'), findsOneWidget);
      expect(profile.marks, 1);
    });

    testWidgets('시작할 때 예약 알림 취소를 한 번만 부른다', (tester) async {
      final scheduler = FakeNotificationScheduler();
      await tester.pumpWidget(
        app(
          scheduler: scheduler,
          profile: FakeProfile(),
          repo: FakeOnboardingGrowthRepo(kind: AvatarKind.acorn),
          growth: FakeGrowthService(growthState()),
          controller: FakeController(),
        ),
      );
      await settle(tester);
      expect(scheduler.cancels, 1);
    });

    testWidgets('예약 알림 취소가 실패해도 앱은 홈을 보여 준다', (tester) async {
      final scheduler = FakeNotificationScheduler()..fail = true;
      await tester.pumpWidget(
        app(
          scheduler: scheduler,
          profile: FakeProfile(),
          repo: FakeOnboardingGrowthRepo(kind: AvatarKind.acorn),
          growth: FakeGrowthService(growthState()),
          controller: FakeController(),
        ),
      );
      await settle(tester);
      expect(scheduler.cancels, 1);
      expect(find.text('러닝'), findsOneWidget);
    });
  });
}
