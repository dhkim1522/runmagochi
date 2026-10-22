import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/core/ui/components.dart';

/// [reduce] 면 시스템 "애니메이션 줄이기" 를 켠 앱으로 [home] 을 그린다.
Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  bool reduce = false,
  bool dark = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? appDarkTheme() : appLightTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
        child: child!,
      ),
      home: home,
    ),
  );
}

double _scale(WidgetTester tester, Finder of) => tester
    .widget<AnimatedScale>(
      find.descendant(of: of, matching: find.byType(AnimatedScale)),
    )
    .scale;

Duration _scaleDuration(WidgetTester tester, Finder of) => tester
    .widget<AnimatedScale>(
      find.descendant(of: of, matching: find.byType(AnimatedScale)),
    )
    .duration;

/// 첫 화면에서 '열기' 를 누르면 [MaterialPageRoute] 로 '둘째 화면' 을 연다.
Widget _opener() => Builder(
  builder: (context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Center(child: Text('둘째 화면'))),
          ),
        ),
        child: const Text('열기'),
      ),
    ),
  ),
);

/// '둘째 화면' 을 감싼 화면 전환의 투명도. 전환이 없으면 1.
double _opacity(WidgetTester tester) {
  final fades = tester.widgetList<FadeTransition>(
    find.ancestor(
      of: find.text('둘째 화면'),
      matching: find.byType(FadeTransition),
    ),
  );
  return fades.fold(1.0, (v, f) => v * f.opacity.value);
}

/// '둘째 화면' 의 위쪽 위치.
double _top(WidgetTester tester) =>
    tester.getTopLeft(find.byType(Scaffold).last).dy;

void main() {
  group('Motion.of', () {
    for (final reduce in [false, true]) {
      testWidgets('애니메이션 줄이기 $reduce 이면 ${reduce ? '0' : '토큰 그대로'}', (
        tester,
      ) async {
        late Duration d;
        late bool r;
        await _pump(
          tester,
          Builder(
            builder: (context) {
              d = Motion.of(context, Motion.enter);
              r = Motion.reduced(context);
              return const SizedBox();
            },
          ),
          reduce: reduce,
        );
        expect(d, reduce ? Duration.zero : Motion.enter);
        expect(r, reduce);
      });
    }

    testWidgets('MediaQuery 가 없어도 토큰 그대로', (tester) async {
      late Duration d;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            d = Motion.of(context, Motion.quick);
            return const SizedBox();
          },
        ),
      );
      expect(d, Motion.quick);
    });
  });

  group('화면 전환', () {
    testWidgets('들어오는 화면은 Motion.enter 동안 나타나며 아래에서 올라온다', (tester) async {
      await _pump(tester, _opener());
      await tester.tap(find.text('열기'));
      await tester.pump();
      await tester.pump(Motion.enter ~/ 3);
      final midOpacity = _opacity(tester);
      final midTop = _top(tester);
      expect(midOpacity, inExclusiveRange(0, 1));
      expect(midTop, greaterThan(0));
      await tester.pump(Motion.enter);
      expect(_opacity(tester), 1);
      expect(_top(tester), 0);
    });

    testWidgets('나가는 화면은 Motion.exit 안에 사라진다', (tester) async {
      await _pump(tester, _opener());
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump();
      await tester.pump(Motion.exit ~/ 2);
      expect(_opacity(tester), inExclusiveRange(0, 1));
      await tester.pump(Motion.exit ~/ 2 + const Duration(milliseconds: 1));
      await tester.pump();
      expect(find.text('둘째 화면'), findsNothing);
    });

    testWidgets('애니메이션 줄이기면 첫 프레임부터 최종 상태(투명도 1, 제자리)', (tester) async {
      await _pump(tester, _opener(), reduce: true);
      await tester.tap(find.text('열기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(_opacity(tester), 1);
      expect(_top(tester), 0);
      expect(
        find.ancestor(
          of: find.text('둘째 화면'),
          matching: find.byType(SlideTransition),
        ),
        findsNothing,
      );
    });
  });

  group('누름 반응', () {
    testWidgets('짧게 톡 눌러도 Motion.press 동안은 눌린 모양이 보인다', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        Scaffold(
          body: Center(
            child: AppButton(label: '시작', onPressed: () => taps++),
          ),
        ),
      );
      final button = find.byType(AppButton);
      final g = await tester.startGesture(tester.getCenter(button));
      await tester.pump();
      await g.up();
      await tester.pump();
      expect(taps, 1);
      expect(_scale(tester, button), Pressable.pressedScale, reason: '바로 놓아도');
      await tester.pump(Motion.press);
      expect(_scale(tester, button), 1);
    });

    testWidgets('길게 누르면 놓을 때 바로 돌아온다', (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: Center(
            child: AppButton(label: '시작', onPressed: () {}),
          ),
        ),
      );
      final button = find.byType(AppButton);
      final g = await tester.startGesture(tester.getCenter(button));
      await tester.pump(Motion.quick);
      expect(_scale(tester, button), Pressable.pressedScale);
      await g.up();
      await tester.pump();
      expect(_scale(tester, button), 1);
    });

    testWidgets('애니메이션 줄이기면 짧게 톡 눌러도 놓자마자 돌아온다', (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: Center(
            child: AppButton(label: '시작', onPressed: () {}),
          ),
        ),
        reduce: true,
      );
      final button = find.byType(AppButton);
      final g = await tester.startGesture(tester.getCenter(button));
      await tester.pump();
      expect(_scale(tester, button), Pressable.pressedScale, reason: '누른 동안');
      await g.up();
      await tester.pump();
      expect(_scale(tester, button), 1, reason: 'Motion.press 만큼 붙잡지 않는다');
    });

    testWidgets('누른 채 화면이 사라져도 타이머가 남지 않는다', (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: Center(
            child: AppButton(label: '시작', onPressed: () {}),
          ),
        ),
      );
      await tester.tap(find.byType(AppButton));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('탭바 탭도 누르면 작아졌다 돌아온다', (tester) async {
      var picked = -1;
      await _pump(
        tester,
        Scaffold(
          bottomNavigationBar: AppTabBar(
            tabs: const [
              AppTab(TabGlyph.run, '러닝'),
              AppTab(TabGlyph.history, '기록'),
            ],
            index: 0,
            onSelected: (i) => picked = i,
          ),
        ),
      );
      final tab = find.ancestor(
        of: find.text('기록'),
        matching: find.byType(Pressable),
      );
      expect(tab, findsOneWidget);
      await tester.tap(find.text('기록'));
      await tester.pump();
      expect(picked, 1);
      expect(_scale(tester, tab), Pressable.pressedScale);
      await tester.pump(Motion.press);
      expect(_scale(tester, tab), 1);
    });

    testWidgets('애니메이션 줄이기면 누름·칩·탭 변화에 시간이 없다', (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppButton(label: '시작', onPressed: () {}),
                AppChip(label: '3km', selected: true, onTap: () {}),
              ],
            ),
          ),
          bottomNavigationBar: AppTabBar(
            tabs: const [
              AppTab(TabGlyph.run, '러닝'),
              AppTab(TabGlyph.history, '기록'),
            ],
            index: 0,
            onSelected: (_) {},
          ),
        ),
        reduce: true,
      );
      expect(_scaleDuration(tester, find.byType(AppButton)), Duration.zero);
      for (final c in tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      )) {
        expect(c.duration, Duration.zero);
      }
    });

    testWidgets('보통은 누름 Motion.press, 칩·탭 Motion.quick', (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: Center(
            child: AppChip(label: '3km', selected: true, onTap: () {}),
          ),
          bottomNavigationBar: AppTabBar(
            tabs: const [
              AppTab(TabGlyph.run, '러닝'),
              AppTab(TabGlyph.history, '기록'),
            ],
            index: 0,
            onSelected: (_) {},
          ),
        ),
      );
      expect(_scaleDuration(tester, find.byType(AppChip)), Motion.press);
      for (final c in tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      )) {
        expect(c.duration, Motion.quick);
      }
    });
  });
}
