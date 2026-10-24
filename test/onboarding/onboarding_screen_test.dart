import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/app/providers.dart';
import 'package:runmagochi/avatar/data/growth_repository.dart';
import 'package:runmagochi/avatar/domain/avatar_name.dart';
import 'package:runmagochi/avatar/domain/growth_rules.dart';
import 'package:runmagochi/avatar/ui/avatar_view.dart';
import 'package:runmagochi/core/korean.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/core/ui/components.dart';
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
  task15Tests();
  testWidgets('1장: 종류별 1단계 소개 문구만 있고 버튼처럼 보이는 안내 카드는 없다', (tester) async {
    for (final (kind, headline) in [
      (AvatarKind.chick, '병아리 알이 왔어요!'),
      (AvatarKind.jelly, '젤리 새싹이 왔어요!'),
      (AvatarKind.acorn, '꼬마 도토리가 왔어요!'),
    ]) {
      await pumpOnboarding(tester, env: OnboardingEnv(kind: kind));
      expect(findText(headline), findsOneWidget, reason: '$kind');
      expect(findText('처음 만나는 러닝 친구'), findsOneWidget);
      expect(findText('달린 거리만큼 자라서 러닝화를 신고, 언젠가 마라토너가 돼요.'), findsOneWidget);
      expect(findText('걷다 뛰다 OK'), findsNothing);
      expect(findText('빨리 달리지 않아도 움직인 만큼 자라요.'), findsNothing);
      expect(find.byType(AppCard), findsNothing);
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
    expect(findText('처음 만나는 러닝 친구'), findsOneWidget);
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
      AppColors.dark.background,
    );
  });
}

/// 작업 15: 새 시스템(사각 무대·입력칸 테마·움직임 토큰).
void task15Tests() {
  for (final dark in [false, true]) {
    final name = dark ? '다크' : '라이트';
    final c = dark ? AppColors.dark : AppColors.light;
    ThemeData theme() => dark ? appDarkTheme() : appLightTheme();

    testWidgets('1장: 마스코트는 사각 무대 위 큰 그림(390×844 에서 6배 이상) ($name)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpOnboarding(tester, theme: theme());
      final stage = find.byKey(const ValueKey('onboarding-stage'));
      expect(stage, findsOneWidget);
      final pet = tester.widget<AvatarView>(
        find.descendant(of: stage, matching: find.byType(AvatarView)),
      );
      expect(pet.scale, greaterThanOrEqualTo(6));
      expect(tester.getSize(stage).width, 390 - 2 * Gap.s5);
      // 무대 위에는 글자가 없고, 제목은 무대 아래.
      expect(
        find.descendant(of: stage, matching: find.byType(Text)),
        findsNothing,
      );
      expect(
        tester.getRect(findText('병아리 알이 왔어요!')).top,
        greaterThan(tester.getRect(stage).bottom),
      );
      final title = tester.widget<Text>(findText('병아리 알이 왔어요!'));
      expect(title.style!.fontSize, 26);
      expect(title.style!.color, c.ink);
    });

    testWidgets('진행 점: 지금 장은 넓은 primaryDeep, 나머지는 lineStrong ($name)', (
      tester,
    ) async {
      await pumpOnboarding(tester, theme: theme());
      final dots = tester
          .widgetList<AnimatedContainer>(
            find.descendant(
              of: find.bySemanticsLabel('2단계 중 1단계'),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .toList();
      expect(dots, hasLength(2));
      final first = dots[0].decoration! as BoxDecoration;
      final second = dots[1].decoration! as BoxDecoration;
      expect(first.color, c.primaryDeep);
      expect(second.color, c.lineStrong);
    });

    testWidgets('2장: 무대 위 마스코트가 이름 말풍선을 단다, 입력칸은 테마 모양 ($name)', (
      tester,
    ) async {
      await pumpOnboarding(tester, theme: theme());
      await goToName(tester);
      final stage = find.byKey(const ValueKey('onboarding-name-stage'));
      expect(stage, findsOneWidget);
      expect(
        find.descendant(of: stage, matching: find.byType(SpeechBubble)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: stage, matching: findText('삐약이')),
        findsOneWidget,
      );
      // 모양은 테마(inputDecorationTheme)가 정한다: 화면이 경계·채움을 따로 주지 않는다.
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration!.enabledBorder, isNull);
      expect(field.decoration!.focusedBorder, isNull);
      expect(field.decoration!.fillColor, isNull);
      final decorator = tester.widget<InputDecorator>(
        find.byType(InputDecorator),
      );
      expect(decorator.decoration.helperText, '1~10자');
      // 이름을 다 지우면 말풍선을 내린다(무대 높이는 그대로).
      final height = tester.getSize(stage).height;
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(
        find.descendant(of: stage, matching: find.byType(SpeechBubble)),
        findsNothing,
      );
      expect(tester.getSize(stage).height, height);
    });
  }

  testWidgets('장 넘김은 Motion.enter 동안 교차해 바뀐다', (tester) async {
    await pumpOnboarding(tester);
    await tester.tap(findText('다음'));
    await tester.pump();
    await tester.pump(Motion.enter ~/ 3);
    expect(findText('병아리 알이 왔어요!'), findsOneWidget, reason: '나가는 장');
    expect(findText('이름을 지어 주세요'), findsOneWidget, reason: '들어오는 장');
    await settle(tester);
    expect(findText('병아리 알이 왔어요!'), findsNothing);
  });

  testWidgets('애니메이션 줄이기면 장이 바로 바뀌고 진행 점도 바로 최종 모양', (tester) async {
    final e = OnboardingEnv();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          growthRepositoryProvider.overrideWithValue(e.repo),
          growthServiceProvider.overrideWithValue(e.growth),
          profileRepositoryProvider.overrideWithValue(e.profile),
        ],
        child: MaterialApp(
          theme: appLightTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: OnboardingScreen(onFinished: () {}),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(findText('다음'));
    await tester.pump();
    await tester.pump();
    expect(findText('병아리 알이 왔어요!'), findsNothing);
    expect(findText('이름을 지어 주세요'), findsOneWidget);
    for (final dot in tester.widgetList<AnimatedContainer>(
      find.descendant(
        of: find.bySemanticsLabel('2단계 중 2단계'),
        matching: find.byType(AnimatedContainer),
      ),
    )) {
      expect(dot.duration, Duration.zero);
    }
  });

  testWidgets('360×640 글자 1.3배: 1장 무대는 줄어도 3배 이상, 넘침 없음', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpOnboarding(tester, textScale: 1.3, theme: appDarkTheme());
    expect(tester.takeException(), isNull);
    final pet = tester.widget<AvatarView>(
      find.descendant(
        of: find.byKey(const ValueKey('onboarding-stage')),
        matching: find.byType(AvatarView),
      ),
    );
    expect(pet.scale, greaterThanOrEqualTo(3));
  });

  group('부화 연출 (F33)', () {
    Finder egg() => find.byKey(const ValueKey('hatch-egg'));
    double petOpacity(WidgetTester tester) => tester
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: find.byType(AvatarView),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;

    testWidgets('1장은 알로 시작해 흔들리다 깨지고 캐릭터가 나온다', (tester) async {
      await pumpOnboarding(tester);
      expect(egg(), findsOneWidget);
      expect(petOpacity(tester), 0);
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(egg(), findsNothing);
      expect(petOpacity(tester), 1);
    });

    testWidgets('누르면 기다리지 않고 바로 태어난다', (tester) async {
      await pumpOnboarding(tester);
      await tester.tap(egg());
      await tester.pump();
      expect(egg(), findsNothing);
      expect(petOpacity(tester), 1);
    });

    testWidgets('움직임 줄이기 설정이면 알 없이 바로 캐릭터', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpOnboarding(tester);
      expect(egg(), findsNothing);
      expect(petOpacity(tester), 1);
    });

    testWidgets('이름 짓기(2장)에서는 알 없이 캐릭터가 서 있다', (tester) async {
      await pumpOnboarding(tester);
      await next(tester);
      expect(egg(), findsNothing);
    });
  });
}
