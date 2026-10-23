import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/domain/growth_rules.dart';
import 'package:runmagochi/avatar/ui/avatar_view.dart';
import 'package:runmagochi/core/theme.dart';

Widget _wrap({
  AvatarKind kind = AvatarKind.chick,
  int stage = 1,
  AvatarMood mood = AvatarMood.normal,
  AvatarAction action = AvatarAction.run,
  int scale = 4,
  String? hat,
  String? accessory,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: AvatarView(
      kind: kind,
      stage: stage,
      mood: mood,
      action: action,
      scale: scale,
      hatItemId: hat,
      accessoryItemId: accessory,
    ),
  ),
);

int _frame(WidgetTester t) =>
    t.state<AvatarViewState>(find.byType(AvatarView)).frameIndex;

Map<String, String> _paths(WidgetTester t) =>
    t.state<AvatarViewState>(find.byType(AvatarView)).layerPaths;

void main() {
  rimTests();
  testWidgets('장착한 모자·소품 레이어가 body, face 뒤 hat, accessory 순서로 붙는다', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(hat: 'cap', accessory: 'sunglasses'));
    expect(_paths(tester).keys.toList(), ['body', 'face', 'hat', 'accessory']);
    expect(_paths(tester)['hat'], 'assets/sprites/chick/hat/cap_run.png');
    expect(
      _paths(tester)['accessory'],
      'assets/sprites/chick/accessory/sunglasses_run.png',
    );
  });

  testWidgets('장착이 바뀌면 레이어가 다시 맞춰진다', (tester) async {
    await tester.pumpWidget(_wrap(hat: 'cap'));
    await tester.pumpWidget(_wrap(hat: 'beanie'));
    expect(_paths(tester)['hat'], contains('beanie_run'));
    await tester.pumpWidget(_wrap());
    expect(_paths(tester).containsKey('hat'), isFalse);
  });

  testWidgets('없는 id 와 부위가 다른 id 는 무시한다', (tester) async {
    await tester.pumpWidget(_wrap(hat: 'nope', accessory: 'cap'));
    expect(_paths(tester).keys.toList(), ['body', 'face']);
  });

  testWidgets('run 은 10fps 4프레임으로 순환한다', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();
    expect(_frame(tester), 0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_frame(tester), 1);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_frame(tester), 0); // 400ms
  });

  testWidgets('action 이 바뀌면 프레임 0부터 2프레임 순환한다', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_frame(tester), 3);

    await tester.pumpWidget(_wrap(action: AvatarAction.idle));
    expect(_frame(tester), 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250)); // 4fps
    expect(_frame(tester), 1);
    await tester.pump(const Duration(milliseconds: 250));
    expect(_frame(tester), 0);
  });

  testWidgets('stage 나 mood 가 바뀌어도 프레임은 이어진다', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(_frame(tester), 2);
    await tester.pumpWidget(_wrap(stage: 2, mood: AvatarMood.sleepy));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_frame(tester), 3);
  });

  testWidgets('TickerMode 가 꺼져 있으면 프레임이 넘어가지 않는다', (tester) async {
    Widget wrap(bool on) => TickerMode(enabled: on, child: _wrap());
    await tester.pumpWidget(wrap(false));
    await tester.pump(const Duration(seconds: 1));
    expect(_frame(tester), 0);
    // 다시 켜면 이어서 돈다.
    await tester.pumpWidget(wrap(true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_frame(tester), 1);
    await tester.pumpWidget(wrap(false));
    await tester.pump(const Duration(seconds: 1));
    expect(_frame(tester), 1);
  });

  testWidgets('앱이 백그라운드면 프레임이 멈추고 앞으로 오면 이어서 돈다', (tester) async {
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 100));
    expect(_frame(tester), 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 1));
    expect(_frame(tester), 1);
    expect(tester.hasRunningAnimations, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_frame(tester), 2);
  });
  testWidgets('크기는 32 × scale 정사각형', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(tester.getSize(find.byType(AvatarView)), const Size(128, 128));
    await tester.pumpWidget(_wrap(scale: 2));
    expect(tester.getSize(find.byType(AvatarView)), const Size(64, 64));
  });

  testWidgets('body·face 두 레이어가 그려진다', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.runAsync(() async {
      final ctx = tester.element(find.byType(AvatarView));
      await precacheImage(
        const AssetImage('assets/sprites/chick/body/stage1_run.png'),
        ctx,
      );
      await precacheImage(
        const AssetImage('assets/sprites/chick/face/normal_run.png'),
        ctx,
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    final render = tester.renderObject(
      find.descendant(
        of: find.byType(AvatarView),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(
      render,
      paints
        ..drawImageRect()
        ..drawImageRect(),
    );
  });

  testWidgets('dispose 후에도 예외가 없다', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}

Widget _themed(ThemeData theme, {int scale = 8}) => MaterialApp(
  theme: theme,
  home: Scaffold(
    body: Center(
      child: AvatarView(
        kind: AvatarKind.acorn,
        stage: 1,
        mood: AvatarMood.normal,
        action: AvatarAction.idle,
        scale: scale,
      ),
    ),
  ),
);

void rimTests() {
  testWidgets('윤곽 두께는 max(1, round(scale/4)) px: 8배 2, 3배 1', (tester) async {
    for (final (scale, want) in [(8, 2), (6, 2), (3, 1)]) {
      await tester.pumpWidget(_themed(appDarkTheme(), scale: scale));
      await tester.pump();
      expect(
        tester.state<AvatarViewState>(find.byType(AvatarView)).rimOffset,
        want,
      );
    }
  });

  testWidgets('다크 테마에서는 테마 토큰 색의 윤곽 층이 뒤에 깔린다', (tester) async {
    await tester.pumpWidget(_themed(appDarkTheme()));
    await tester.pump();
    expect(find.byKey(avatarRimKey), findsOneWidget);
    expect(
      tester.state<AvatarViewState>(find.byType(AvatarView)).rimColor,
      AppColors.dark.spriteRim,
    );
    // 윤곽이 스프라이트보다 먼저(뒤에) 그려진다.
    final painters = find.descendant(
      of: find.byType(AvatarView),
      matching: find.byType(CustomPaint),
    );
    expect(tester.widget<CustomPaint>(painters.first).key, avatarRimKey);
  });

  testWidgets('라이트 테마에서는 윤곽 층이 없다', (tester) async {
    await tester.pumpWidget(_themed(appLightTheme()));
    await tester.pump();
    expect(find.byKey(avatarRimKey), findsNothing);
    expect(
      tester.state<AvatarViewState>(find.byType(AvatarView)).rimColor,
      isNull,
    );
  });
}
