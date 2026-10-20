import 'dart:async';

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
  FakeOnboardingGrowthRepo({this.kind = AvatarKind.chick, this.name = '러니'});

  AvatarKind kind;
  String name;
  final List<String> names = [];

  /// true 면 setAvatarName 이 실패한다.
  bool nameFails = false;

  @override
  Future<AvatarKind> avatarKind() async => kind;

  @override
  Future<String> avatarName() async => name;

  /// 지정하면 setAvatarName 이 이 Completer 가 끝날 때까지 기다린다.
  Completer<void>? holdName;

  @override
  Future<void> setAvatarName(String n) async {
    await holdName?.future;
    if (nameFails) throw StateError('name failed');
    if (validateAvatarName(n) != null) throw ArgumentError(n);
    names.add(n.trim());
    name = n.trim();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class OnboardingEnv {
  OnboardingEnv({AvatarKind kind = AvatarKind.chick, String name = '러니'})
    : repo = FakeOnboardingGrowthRepo(kind: kind, name: name);

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

Future<void> goToName(WidgetTester tester) => next(tester);

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

  testWidgets('첫 실행은 2장이고 주간 목표를 묻지 않는다', (tester) async {
    await pumpOnboarding(tester);
    expect(findText('다음'), findsOneWidget);
    await next(tester);
    expect(findText('이름을 지어 주세요'), findsOneWidget);
    expect(findText('다음'), findsNothing);
    expect(findText('시작하기'), findsOneWidget);
    expect(find.textContaining('주간 목표'), findsNothing);
    expect(find.textContaining('이번 주 목표'), findsNothing);
  });

  testWidgets('제목은 헤더, 진행 점은 몇 번째 장인지 읽힌다', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpOnboarding(tester);
    expect(find.bySemanticsLabel('2단계 중 1단계'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('병아리 알이 왔어요!')),
      matchesSemantics(label: '병아리 알이 왔어요!', isHeader: true),
    );
    await next(tester);
    expect(find.bySemanticsLabel('2단계 중 2단계'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('이름을 지어 주세요')),
      matchesSemantics(label: '이름을 지어 주세요', isHeader: true),
    );
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

  testWidgets('2장: 빈 이름·10자 넘는 이름은 안내하고 시작하기를 막는다', (tester) async {
    final handle = tester.ensureSemantics();
    final e = await pumpOnboarding(tester);
    await next(tester);
    expect(enabled(tester, '시작하기'), isTrue);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(findText('이름을 입력해 주세요'), findsOneWidget);
    expect(enabled(tester, '시작하기'), isFalse);
    await tester.tap(findText('시작하기'));
    await settle(tester);
    expect(findText('이름을 지어 주세요'), findsOneWidget, reason: '2장에 머문다');
    expect(e.finished, 0);

    await tester.enterText(find.byType(TextField), '가나다라마바사아자차카');
    await tester.pump();
    expect(findText('10자까지 쓸 수 있어요'), findsOneWidget);
    expect(enabled(tester, '시작하기'), isFalse);

    await tester.enterText(find.byType(TextField), '가나다라마바사아자차');
    await settle(tester); // 오류 문구가 사라지는 애니메이션
    expect(findText('10자까지 쓸 수 있어요'), findsNothing);
    expect(enabled(tester, '시작하기'), isTrue);
    handle.dispose();
  });

  testWidgets('이전 버튼과 시스템 뒤로 가기는 앞 장으로 간다', (tester) async {
    await pumpOnboarding(tester);
    await goToName(tester);
    expect(findText('이름을 지어 주세요'), findsOneWidget);

    await previous(tester);
    expect(findText('병아리 알이 왔어요!'), findsOneWidget);

    await goToName(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(findText('병아리 알이 왔어요!'), findsOneWidget);
  });

  testWidgets('뒤로 갔다 와도 입력한 이름이 남는다', (tester) async {
    await pumpOnboarding(tester);
    await next(tester);
    await tester.enterText(find.byType(TextField), '구름');
    await previous(tester);
    await next(tester);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '구름');
  });

  testWidgets('저장하는 동안 시스템 뒤로 가기는 장을 바꾸지 않는다', (tester) async {
    final e = await pumpOnboarding(tester);
    await goToName(tester);
    final hold = e.repo.holdName = Completer<void>();
    await tester.tap(findText('시작하기'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(findText('이름을 지어 주세요'), findsOneWidget);
    expect(e.finished, 0);

    hold.complete();
    await settle(tester);
    expect(e.finished, 1);
    expect(e.repo.names, ['삐약이']);
  });

  testWidgets('2장의 시작하기: 이름을 저장하고 완료를 한 번 표시한다', (tester) async {
    final e = await pumpOnboarding(tester);
    await next(tester);
    await tester.enterText(find.byType(TextField), '  구름  ');
    await tapText(tester, '시작하기');
    expect(e.repo.names, ['구름']);
    expect(e.profile.marks, 1);
    expect(e.profile.onboarded, isTrue);
    expect(e.finished, 1);
  });

  testWidgets('시작하기를 두 번 눌러도 한 번만 저장한다', (tester) async {
    final e = await pumpOnboarding(tester);
    await goToName(tester);
    await tester.tap(findText('시작하기'));
    await tester.tap(findText('시작하기'), warnIfMissed: false);
    await settle(tester);
    expect(e.profile.marks, 1);
    expect(e.finished, 1);
    expect(e.repo.names, ['삐약이']);
  });

  testWidgets('저장에 실패하면 알리고 첫 실행 화면에 머문다', (tester) async {
    final e = OnboardingEnv();
    e.profile.markFails = true;
    await pumpOnboarding(tester, env: e);
    await goToName(tester);
    await tapText(tester, '시작하기');
    expect(findText('저장하지 못했어요'), findsOneWidget);
    expect(findText('이름을 지어 주세요'), findsOneWidget);
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

  testWidgets('360×640, 글자 1.3배에서 두 장 모두 overflow 없이 그려진다', (tester) async {
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
  });

  testWidgets('다크 테마로 그려진다', (tester) async {
    await pumpOnboarding(tester, theme: appDarkTheme());
    expect(tester.takeException(), isNull);
    await goToName(tester);
    expect(tester.takeException(), isNull);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(
      scaffold.backgroundColor ?? appDarkTheme().scaffoldBackgroundColor,
      AppColors.dark.cream,
    );
  });
}
