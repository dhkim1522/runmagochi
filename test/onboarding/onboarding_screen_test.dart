import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/app/providers.dart';
import 'package:runmagochi/avatar/data/growth_repository.dart';
import 'package:runmagochi/avatar/domain/avatar_name.dart';
import 'package:runmagochi/avatar/domain/growth_rules.dart';
import 'package:runmagochi/core/korean.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/onboarding/ui/onboarding_screen.dart';
import 'package:runmagochi/profile/app/providers.dart';
import 'package:runmagochi/run/app/providers.dart';

import '../run/ui/fakes.dart';

/// find.text 와 같되 단어 잇기 문자([keepAll])를 빼고 비교한다.
Finder findText(String s) => find.byWidgetPredicate((w) {
  final data = switch (w) {
    Text(:final data) => data,
    EditableText(:final controller) => controller.text,
    _ => null,
  };
  return data?.replaceAll(wordJoiner, '') == s;
}, description: 'text "$s"');

/// 첫 실행 화면이 읽고 쓰는 성장 저장소 가짜.
class FakeOnboardingGrowthRepo implements GrowthRepository {
  FakeOnboardingGrowthRepo({
    this.kind = AvatarKind.chick,
    this.name = '러니',
    this.targetM = 10000,
  });

  AvatarKind kind;
  String name;
  double targetM;
  final List<String> names = [];
  final List<DateTime> targetWeeks = [];

  /// true 면 setAvatarName 이 실패한다.
  bool nameFails = false;

  @override
  Future<AvatarKind> avatarKind() async => kind;

  @override
  Future<String> avatarName() async => name;

  @override
  Future<void> setAvatarName(String n) async {
    if (nameFails) throw StateError('name failed');
    if (validateAvatarName(n) != null) throw ArgumentError(n);
    names.add(n.trim());
    name = n.trim();
  }

  @override
  Future<double> weeklyTarget(DateTime weekStart) async {
    targetWeeks.add(weekStart);
    return targetM;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class OnboardingEnv {
  OnboardingEnv({
    AvatarKind kind = AvatarKind.chick,
    String name = '러니',
    double targetM = 10000,
  }) : repo = FakeOnboardingGrowthRepo(
         kind: kind,
         name: name,
         targetM: targetM,
       );

  final FakeOnboardingGrowthRepo repo;
  final growth = FakeGrowthService(growthState());
  final profile = FakeProfile(onboarded: false);
  int finished = 0;
}

Future<OnboardingEnv> pumpOnboarding(
  WidgetTester tester, {
  OnboardingEnv? env,
  double textScale = 1,
  ThemeData? theme,
}) async {
  final e = env ?? OnboardingEnv();
  await tester.pumpWidget(
    ProviderScope(
      // 한 테스트에서 다시 그려도 새 화면으로 시작한다.
      key: UniqueKey(),
      overrides: [
        growthRepositoryProvider.overrideWithValue(e.repo),
        growthServiceProvider.overrideWithValue(e.growth),
        profileRepositoryProvider.overrideWithValue(e.profile),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 17)),
      ],
      child: MaterialApp(
        theme: theme ?? appLightTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: OnboardingScreen(onFinished: () => e.finished++),
      ),
    ),
  );
  await settle(tester);
  return e;
}

/// 아바타 티커가 멈추지 않아 pumpAndSettle 대신 고정 시간만 흘린다.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(findText(text));
  await tester.pump();
  await tester.tap(findText(text));
  await settle(tester);
}

Future<void> next(WidgetTester tester) => tapText(tester, '다음');
Future<void> previous(WidgetTester tester) => tapText(tester, '이전');

Future<void> goToGoal(WidgetTester tester) async {
  await next(tester);
  await next(tester);
}

bool enabled(WidgetTester tester, String label) => isSemantics(
  isEnabled: true,
).matches(tester.getSemantics(find.bySemanticsLabel(label).last), {});

void main() {
  testWidgets('1장: 종류별 1단계 소개 문구와 걷다 뛰다 OK 카드', (tester) async {
    for (final (kind, headline) in [
      (AvatarKind.chick, '병아리 알이 왔어요!'),
      (AvatarKind.jelly, '젤리 새싹이 왔어요!'),
      (AvatarKind.acorn, '꼬마 도토리가 왔어요!'),
    ]) {
      await pumpOnboarding(tester, env: OnboardingEnv(kind: kind));
      expect(findText(headline), findsOneWidget, reason: '$kind');
      expect(findText('처음 만나는 러닝 친구'), findsOneWidget);
      expect(findText('달린 거리만큼 자라서 러닝화를 신고, 언젠가 마라토너가 돼요.'), findsOneWidget);
      expect(findText('걷다 뛰다 OK'), findsOneWidget);
      expect(findText('빨리 달리지 않아도 움직인 만큼 자라요.'), findsOneWidget);
      expect(findText('이전'), findsNothing);
      expect(findText('다음'), findsOneWidget);
    }
  });

  testWidgets('제목은 헤더, 진행 점은 몇 번째 장인지 읽힌다', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpOnboarding(tester);
    expect(find.bySemanticsLabel('3단계 중 1단계'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('병아리 알이 왔어요!')),
      matchesSemantics(label: '병아리 알이 왔어요!', isHeader: true),
    );
    await next(tester);
    expect(find.bySemanticsLabel('3단계 중 2단계'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('이름을 지어 주세요')),
      matchesSemantics(label: '이름을 지어 주세요', isHeader: true),
    );
    await next(tester);
    expect(find.bySemanticsLabel('3단계 중 3단계'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('2장: 종류별 추천 이름이 들어 있고 미리보기에 바로 보인다', (tester) async {
    for (final (kind, suggestion) in [
      (AvatarKind.chick, '삐약이'),
      (AvatarKind.jelly, '말랑이'),
      (AvatarKind.acorn, '토리'),
    ]) {
      await pumpOnboarding(tester, env: OnboardingEnv(kind: kind));
      await next(tester);
      expect(findText('이름을 지어 주세요'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, suggestion, reason: '$kind');
      // 입력칸 + 미리보기
      expect(findText(suggestion), findsNWidgets(2));
      expect(findText('${suggestion.runes.length}/10'), findsOneWidget);
    }
    await tester.enterText(find.byType(TextField), '도토리묵');
    await tester.pump();
    expect(findText('도토리묵'), findsNWidgets(2));
    expect(findText('4/10'), findsOneWidget);
  });

  testWidgets('2장: 기존 사용자가 바꾼 이름은 그대로 채운다', (tester) async {
    await pumpOnboarding(
      tester,
      env: OnboardingEnv(kind: AvatarKind.jelly, name: '콩떡'),
    );
    await next(tester);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '콩떡');
  });

  testWidgets('2장: 빈 이름·10자 넘는 이름은 안내하고 다음을 막는다', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpOnboarding(tester);
    await next(tester);
    expect(enabled(tester, '다음'), isTrue);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(findText('이름을 입력해 주세요'), findsOneWidget);
    expect(enabled(tester, '다음'), isFalse);
    await tester.tap(findText('다음'));
    await settle(tester);
    expect(findText('이름을 지어 주세요'), findsOneWidget, reason: '2장에 머문다');

    await tester.enterText(find.byType(TextField), '가나다라마바사아자차카');
    await tester.pump();
    expect(findText('10자까지 쓸 수 있어요'), findsOneWidget);
    expect(enabled(tester, '다음'), isFalse);

    await tester.enterText(find.byType(TextField), '가나다라마바사아자차');
    await settle(tester); // 오류 문구가 사라지는 애니메이션
    expect(findText('10자까지 쓸 수 있어요'), findsNothing);
    expect(enabled(tester, '다음'), isTrue);
    await next(tester);
    expect(findText('이번 주 목표를 정해요'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('이전 버튼과 시스템 뒤로 가기는 앞 장으로 간다', (tester) async {
    await pumpOnboarding(tester);
    await goToGoal(tester);
    expect(findText('이번 주 목표를 정해요'), findsOneWidget);

    await previous(tester);
    expect(findText('이름을 지어 주세요'), findsOneWidget);
    await previous(tester);
    expect(findText('병아리 알이 왔어요!'), findsOneWidget);

    await goToGoal(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(findText('이름을 지어 주세요'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(findText('병아리 알이 왔어요!'), findsOneWidget);
  });

  testWidgets('뒤로 갔다 와도 입력한 이름이 남는다', (tester) async {
    await pumpOnboarding(tester);
    await next(tester);
    await tester.enterText(find.byType(TextField), '구름');
    await next(tester);
    await previous(tester);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '구름');
  });

  testWidgets('3장: 5개 카드, 새 사용자는 10km 가 골라져 있고 라디오로 읽힌다', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpOnboarding(tester);
    await goToGoal(tester);
    for (final t in ['3km', '5km', '10km', '15km', '20km']) {
      expect(findText(t), findsOneWidget);
    }
    for (final t in ['첫걸음', '가볍게', '추천', '꾸준히', '도전']) {
      expect(findText(t), findsOneWidget);
    }
    expect(
      findText('10km 는 주 3번 3km 남짓이에요. 목표는 홈과 설정에서 언제든 바꿀 수 있어요(최소 3km).'),
      findsOneWidget,
    );
    expect(
      findText('목표를 채우면 삐약이가 경험치 +50 을 받아요. 매일 달리지 않아도 돼요.'),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('10km, 추천')),
      matchesSemantics(
        label: '10km, 추천',
        hasCheckedState: true,
        isChecked: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('5km, 가볍게')),
      matchesSemantics(
        label: '5km, 가볍게',
        hasCheckedState: true,
        isChecked: false,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(findText('5km'));
    await tester.pump();
    expect(
      tester.getSemantics(find.bySemanticsLabel('5km, 가볍게')),
      isSemantics(isChecked: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('10km, 추천')),
      isSemantics(isChecked: false),
    );
    final size = tester.getSize(
      find
          .ancestor(of: findText('5km'), matching: find.byType(GestureDetector))
          .first,
    );
    expect(size.height, greaterThanOrEqualTo(48));
    handle.dispose();
  });

  testWidgets('3장 안내 문구는 입력한 이름에 맞는 조사를 쓴다', (tester) async {
    await pumpOnboarding(tester);
    await next(tester);
    await tester.enterText(find.byType(TextField), '말랑');
    await tester.pump();
    await next(tester);
    expect(
      findText('목표를 채우면 말랑이 경험치 +50 을 받아요. 매일 달리지 않아도 돼요.'),
      findsOneWidget,
    );
  });

  testWidgets('시작하기: 이름·목표를 저장하고 완료를 한 번 표시한다', (tester) async {
    final e = await pumpOnboarding(tester);
    await next(tester);
    await tester.enterText(find.byType(TextField), '  구름  ');
    await next(tester);
    await tester.tap(findText('5km'));
    await tester.pump();
    await tapText(tester, '시작하기');
    expect(e.repo.names, ['구름']);
    expect(e.growth.targets, [5000]);
    expect(e.profile.marks, 1);
    expect(e.profile.onboarded, isTrue);
    expect(e.finished, 1);
  });

  testWidgets('시작하기를 두 번 눌러도 한 번만 저장한다', (tester) async {
    final e = await pumpOnboarding(tester);
    await goToGoal(tester);
    await tester.tap(findText('시작하기'));
    await tester.tap(findText('시작하기'), warnIfMissed: false);
    await settle(tester);
    expect(e.profile.marks, 1);
    expect(e.finished, 1);
    expect(e.repo.names, ['삐약이']);
    expect(e.growth.targets, [10000]);
  });

  testWidgets('기존 사용자: 지금 목표가 다섯 중 하나면 그 카드가 골라져 있다', (tester) async {
    final handle = tester.ensureSemantics();
    final e = await pumpOnboarding(tester, env: OnboardingEnv(targetM: 15000));
    await goToGoal(tester);
    expect(
      tester.getSemantics(find.bySemanticsLabel('15km, 꾸준히')),
      isSemantics(isChecked: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('10km, 추천')),
      isSemantics(isChecked: false),
    );
    expect(e.repo.targetWeeks, [DateTime(2026, 10, 12)]);
    handle.dispose();
  });

  testWidgets('기존 사용자: 지금 목표가 다섯에 없으면 아무것도 고르지 않고 목표를 그대로 둔다', (tester) async {
    final handle = tester.ensureSemantics();
    final e = await pumpOnboarding(tester, env: OnboardingEnv(targetM: 7000));
    await goToGoal(tester);
    for (final l in [
      '3km, 첫걸음',
      '5km, 가볍게',
      '10km, 추천',
      '15km, 꾸준히',
      '20km, 도전',
    ]) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(l)),
        isSemantics(isChecked: false),
        reason: l,
      );
    }
    await tapText(tester, '시작하기');
    expect(e.growth.targets, isEmpty);
    expect(e.profile.marks, 1);
    expect(e.finished, 1);
    handle.dispose();
  });

  testWidgets('저장에 실패하면 알리고 첫 실행 화면에 머문다', (tester) async {
    final e = OnboardingEnv();
    e.profile.markFails = true;
    await pumpOnboarding(tester, env: e);
    await goToGoal(tester);
    await tapText(tester, '시작하기');
    expect(findText('저장하지 못했어요'), findsOneWidget);
    expect(findText('이번 주 목표를 정해요'), findsOneWidget);
    expect(e.finished, 0);
    expect(e.profile.onboarded, isFalse);

    // 다시 누를 수 있다.
    e.profile.markFails = false;
    await tapText(tester, '시작하기');
    expect(e.finished, 1);
  });

  testWidgets('버튼은 하나의 버튼 노드다', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpOnboarding(tester);
    await next(tester);
    expect(
      tester.getSemantics(find.bySemanticsLabel('이전')),
      matchesSemantics(
        label: '이전',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('360×640, 글자 1.3배에서 세 장 모두 overflow 없이 그려진다', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpOnboarding(tester, textScale: 1.3);
    expect(tester.takeException(), isNull);
    expect(findText('걷다 뛰다 OK'), findsOneWidget);
    await next(tester);
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), '가나다라마바사아자차');
    await tester.pump();
    expect(tester.takeException(), isNull);
    await next(tester);
    expect(tester.takeException(), isNull);
    expect(findText('20km'), findsOneWidget);
  });

  testWidgets('다크 테마로 그려진다', (tester) async {
    await pumpOnboarding(tester, theme: appDarkTheme());
    expect(tester.takeException(), isNull);
    await goToGoal(tester);
    expect(tester.takeException(), isNull);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(
      scaffold.backgroundColor ?? appDarkTheme().scaffoldBackgroundColor,
      AppColors.dark.cream,
    );
  });
}
