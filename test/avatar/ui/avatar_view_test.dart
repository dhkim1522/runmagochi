import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/domain/growth_rules.dart';
import 'package:runmagochi/avatar/ui/avatar_view.dart';

Widget _wrap({
  int stage = 1,
  AvatarMood mood = AvatarMood.normal,
  AvatarAction action = AvatarAction.run,
  int scale = 4,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: AvatarView(stage: stage, mood: mood, action: action, scale: scale),
  ),
);

int _frame(WidgetTester t) =>
    t.state<AvatarViewState>(find.byType(AvatarView)).frameIndex;

void main() {
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
        const AssetImage('assets/sprites/body/stage1_run.png'),
        ctx,
      );
      await precacheImage(
        const AssetImage('assets/sprites/face/normal_run.png'),
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
