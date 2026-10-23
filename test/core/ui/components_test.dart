import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/ui/sprite_sheet.dart';
import 'package:runmagochi/core/stage/stage_scene.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/core/ui/components.dart';

/// 360×640 화면에 [child] 를 그린다. [scale] 은 시스템 글자 배율.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool dark = false,
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? appDarkTheme() : appLightTheme(),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 640),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.s5),
            child: Center(child: child),
          ),
        ),
      ),
    ),
  );
}

AppColors _c(bool dark) => dark ? AppColors.dark : AppColors.light;

BoxDecoration _decoration(WidgetTester tester, Finder of) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(of: of, matching: find.byType(DecoratedBox)).first,
  );
  return box.decoration as BoxDecoration;
}

double _scale(WidgetTester tester, Finder of) => tester
    .widget<AnimatedScale>(
      find.descendant(of: of, matching: find.byType(AnimatedScale)),
    )
    .scale;

void main() {
  _buttonTests();
  _chipTests();
  _barCardTests();
  _coinTabTests();
  _stageTests();
  _bubbleHeightTest();
  _dialogTests();
  _task14Tests();
  _task15Tests();

  testWidgets('ScreenTitle 은 헤더로 표시된다', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const ScreenTitle('기록'));
    expect(
      tester.getSemantics(find.byType(ScreenTitle)),
      matchesSemantics(label: '기록', isHeader: true),
    );
    handle.dispose();
  });
}

void _buttonTests() {
  testWidgets('AppButton 은 높이 60 알약에 라벨이 보이고 탭하면 불린다', (tester) async {
    var taps = 0;
    await _pump(tester, AppButton(label: '시작', onPressed: () => taps++));
    expect(find.text('시작'), findsOneWidget);
    await tester.tap(find.text('시작'));
    expect(taps, 1);
    expect(AppButton.height, 60);
    final size = tester.getSize(find.byType(AppButton));
    expect(size.height, AppButton.height);
    expect(size.width, greaterThanOrEqualTo(48));
  });

  testWidgets('AppButton.secondary small 은 높이 48, 글자 body-strong 17 의 흰 알약', (
    tester,
  ) async {
    var taps = 0;
    await _pump(
      tester,
      AppButton.secondary(
        label: '끝부분 잘라내기',
        small: true,
        onPressed: () => taps++,
      ),
    );
    final c = _c(false);
    expect(
      tester.getSize(find.byType(AppButton)).height,
      AppButton.smallHeight,
    );
    expect(AppButton.smallHeight, 48);
    final style = tester.widget<Text>(find.text('끝부분 잘라내기')).style!;
    expect(style.fontSize, 17);
    expect(style.color, c.ink);
    await tester.tap(find.text('끝부분 잘라내기'));
    expect(taps, 1);
  });

  testWidgets('AppButton 은 onPressed 가 null 이면 눌리지 않고 50% 로 흐리다', (
    tester,
  ) async {
    await _pump(tester, const AppButton(label: '시작', onPressed: null));
    await tester.tap(find.text('시작'));
    await tester.pump();
    final opacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byType(AppButton),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, 0.5);
  });

  testWidgets('AppButton 은 라벨과 버튼이 한 시맨틱 노드다', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, AppButton(label: '시작', onPressed: () {}));
    expect(
      tester.getSemantics(find.byType(AppButton)),
      matchesSemantics(
        label: '시작',
        isButton: true,
        isEnabled: true,
        hasEnabledState: true,
        hasTapAction: true,
      ),
    );
    expect(find.bySemanticsLabel('시작'), findsOneWidget);
    handle.dispose();
  });

  for (final dark in [false, true]) {
    final name = dark ? '다크' : '라이트';
    testWidgets('AppButton 세 가지 색과 경계선 ($name)', (tester) async {
      final c = _c(dark);
      await _pump(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(key: const Key('p'), label: '시작', onPressed: () {}),
            AppButton.secondary(
              key: const Key('s'),
              label: '이전',
              onPressed: () {},
            ),
            AppButton.panel(
              key: const Key('d'),
              label: '일시정지',
              onPressed: () {},
            ),
          ],
        ),
        dark: dark,
      );
      final p = _decoration(tester, find.byKey(const Key('p')));
      expect(p.color, c.primary);
      expect(p.border, Border.all(color: c.primaryEdge, width: Borders.edge));
      expect(p.boxShadow, isNull);
      expect(tester.widget<Text>(find.text('시작')).style!.color, c.onPrimary);

      final s = _decoration(tester, find.byKey(const Key('s')));
      expect(s.color, c.surface);
      expect(s.border, Border.all(color: c.lineStrong, width: Borders.edge));
      expect(tester.widget<Text>(find.text('이전')).style!.color, c.ink);

      final d = _decoration(tester, find.byKey(const Key('d')));
      expect(d.color, c.panel);
      expect(d.border, isNull);
      expect(tester.widget<Text>(find.text('일시정지')).style!.color, c.onPanel);
    });
  }

  testWidgets('AppButton 누름: 0.97 로 작아졌다가 놓으면 돌아온다', (tester) async {
    await _pump(tester, AppButton(label: '시작', onPressed: () {}));
    final button = find.byType(AppButton);
    expect(_scale(tester, button), 1);
    final g = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    expect(_scale(tester, button), Pressable.pressedScale);
    expect(Pressable.pressedScale, 0.97);
    // 누르는 동안에도 자리(레이아웃)는 그대로다.
    final rect = tester.getRect(button);
    await tester.pump(Motion.press);
    expect(tester.getRect(button), rect);
    await g.up();
    await tester.pump();
    expect(_scale(tester, button), 1);
  });

  testWidgets('비활성 AppButton 은 눌러도 작아지지 않는다', (tester) async {
    await _pump(tester, const AppButton(label: '시작', onPressed: null));
    final button = find.byType(AppButton);
    final g = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    expect(_scale(tester, button), 1);
    await g.up();
  });

  for (final dark in [false, true]) {
    testWidgets(
      'AppButton 두 개가 나란히 글자 2배에서도 넘치지 않는다 (${dark ? '다크' : '라이트'})',
      (tester) async {
        await _pump(
          tester,
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(label: '끝부분 잘라내기', onPressed: () {}),
              ),
              const SizedBox(width: Gap.s3),
              Expanded(
                child: AppButton(label: '확인', onPressed: () {}),
              ),
            ],
          ),
          dark: dark,
          scale: 2,
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(AppButton).first).height,
          greaterThanOrEqualTo(AppButton.height),
        );
      },
    );
  }
}

void _chipTests() {
  Widget chips({bool second = true}) => ChipRow(
    children: [
      AppChip(label: '3km', selected: false, onTap: () {}),
      AppChip(label: '5km', selected: second, onTap: () {}),
      AppChip(label: '10km', selected: false, onTap: () {}),
      AppChip(
        label: '직접',
        semanticLabel: '목표 직접 입력',
        selected: false,
        onTap: () {},
      ),
    ],
  );

  for (final dark in [false, true]) {
    final name = dark ? '다크' : '라이트';
    testWidgets('AppChip 선택 표시는 연두 면 + primaryEdge 경계선 하나 ($name)', (
      tester,
    ) async {
      final c = _c(dark);
      await _pump(tester, chips(), dark: dark);
      final on = _decoration(tester, find.widgetWithText(AppChip, '5km'));
      expect(on.color, c.primary);
      expect(on.border, Border.all(color: c.primaryEdge, width: Borders.edge));
      expect(tester.widget<Text>(find.text('5km')).style!.color, c.onPrimary);

      final off = _decoration(tester, find.widgetWithText(AppChip, '3km'));
      expect(off.color, c.surfaceSoft);
      // 경계선 자리는 같고 색만 면과 같아 보이지 않는다(선택이 바뀌어도 크기가 같다).
      expect(off.border, Border.all(color: c.surfaceSoft, width: Borders.edge));
      expect(tester.widget<Text>(find.text('3km')).style!.color, c.ink);
    });
  }

  testWidgets('AppChip 은 높이 48·폭 48 이상이고 선택 상태가 시맨틱에 있다', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await _pump(
      tester,
      ChipRow(
        children: [
          AppChip(label: '거리', selected: true, onTap: () => taps++),
          AppChip(label: '시간', selected: false, onTap: () {}),
        ],
      ),
    );
    for (final chip in tester.widgetList(find.byType(AppChip))) {
      final size = tester.getSize(find.byWidget(chip));
      expect(size.height, greaterThanOrEqualTo(AppChip.height));
      expect(size.width, greaterThanOrEqualTo(48));
    }
    expect(AppChip.height, 48);
    expect(
      tester.getSemantics(find.widgetWithText(AppChip, '거리')),
      matchesSemantics(
        label: '거리',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(find.text('거리'));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('AppChip 의 semanticLabel 이 라벨 대신 읽힌다', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, chips());
    expect(find.bySemanticsLabel('목표 직접 입력'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('AppChip 누름: 작아졌다가 돌아온다', (tester) async {
    await _pump(tester, chips());
    final chip = find.widgetWithText(AppChip, '3km');
    final g = await tester.startGesture(tester.getCenter(chip));
    await tester.pump();
    expect(_scale(tester, chip), Pressable.pressedScale);
    await g.up();
    // 짧게 눌러도 Motion.press 동안은 눌린 모양이 남는다(작업 15).
    await tester.pump(Motion.press);
    expect(_scale(tester, chip), 1);
  });

  for (final dark in [false, true]) {
    testWidgets('칩 4개 줄이 글자 2배에서도 넘치지 않는다 (${dark ? '다크' : '라이트'})', (
      tester,
    ) async {
      await _pump(tester, chips(), dark: dark, scale: 2);
      expect(tester.takeException(), isNull);
    });
  }
}

void _barCardTests() {
  for (final dark in [false, true]) {
    final name = dark ? '다크' : '라이트';
    testWidgets('ProgressBar 는 높이 12, 트랙 surfaceSoft·채움 primaryDeep ($name)', (
      tester,
    ) async {
      final c = _c(dark);
      await _pump(
        tester,
        const SizedBox(width: 200, child: ProgressBar(value: 1.5)),
        dark: dark,
      );
      expect(tester.getSize(find.byType(ProgressBar)).height, 12);
      final f = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(f.widthFactor, 1.0);
      final track = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(ProgressBar),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(track.color, c.surfaceSoft);
      final fill = _decoration(tester, find.byType(FractionallySizedBox));
      expect(fill.color, c.primaryDeep);
    });
  }

  testWidgets('ProgressBar 는 음수를 0 으로 자른다', (tester) async {
    await _pump(
      tester,
      const SizedBox(width: 200, child: ProgressBar(value: -1)),
    );
    final f = tester.widget<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(f.widthFactor, 0.0);
  });

  testWidgets('ProgressBar 에 이름을 주면 이름과 % 값을 읽힌다', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const SizedBox(
        width: 200,
        child: ProgressBar(value: 0.94, semanticLabel: '레벨 경험치'),
      ),
    );
    expect(
      tester.getSemantics(find.byType(ProgressBar)),
      matchesSemantics(label: '레벨 경험치', value: '94%'),
    );
    handle.dispose();
  });

  for (final dark in [false, true]) {
    final name = dark ? '다크' : '라이트';
    testWidgets('AppCard 는 테두리·그림자 없는 surface 판이다 ($name)', (tester) async {
      final c = _c(dark);
      await _pump(
        tester,
        const AppCard(padding: EdgeInsets.all(Gap.s5), child: Text('카드')),
        dark: dark,
      );
      final d = _decoration(tester, find.byType(AppCard));
      expect(d.color, c.surface);
      expect(d.border, isNull);
      expect(d.boxShadow, isNull);
      expect(d.borderRadius, BorderRadius.circular(Radii.lg));
      // 아래 립 자리가 없어 카드 크기 = 글자 + 안쪽 여백.
      final text = tester.getSize(find.text('카드'));
      expect(
        tester.getSize(find.byType(AppCard)).height,
        text.height + 2 * Gap.s5,
      );
    });
  }

  testWidgets('AppCard 에 borderColor 를 주면 Borders.edge 경계선을 두른다', (
    tester,
  ) async {
    const c = AppColors.light;
    await _pump(
      tester,
      AppCard(borderColor: c.primaryEdge, child: const Text('카드')),
    );
    final d = _decoration(tester, find.byType(AppCard));
    expect(d.border, Border.all(color: c.primaryEdge, width: Borders.edge));
  });

  for (final dark in [false, true]) {
    testWidgets('StatCard 3칸이 글자 2배에서도 넘치지 않는다 (${dark ? '다크' : '라이트'})', (
      tester,
    ) async {
      await _pump(
        tester,
        const Row(
          children: [
            Expanded(
              child: StatCard(label: '평균 페이스', value: "6'08\""),
            ),
            SizedBox(width: Gap.s3),
            Expanded(
              child: StatCard(label: '시간', value: '1:32:09'),
            ),
            SizedBox(width: Gap.s3),
            Expanded(
              child: StatCard(label: '칼로리', value: '353'),
            ),
          ],
        ),
        dark: dark,
        scale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('시간'), findsOneWidget);
      expect(find.text('1:32:09'), findsOneWidget);
    });

    testWidgets(
      'StatsCard: 흰 카드 하나에 지표 칸이 같은 폭으로 들어간다 (${dark ? '다크' : '라이트'})',
      (tester) async {
        final c = _c(dark);
        await _pump(
          tester,
          const StatsCard(
            cells: [
              StatCard.cell(label: '평균 페이스', value: "6'08\""),
              StatCard.cell(label: '현재 페이스', value: "6'02\""),
              StatCard.cell(label: '시간', value: '1:32:09'),
            ],
          ),
          dark: dark,
          scale: 2,
        );
        expect(tester.takeException(), isNull);
        // 카드는 하나다(칸은 판을 따로 그리지 않는다).
        expect(find.byType(AppCard), findsOneWidget);
        final d = _decoration(tester, find.byType(StatsCard));
        expect(d.color, c.surface);
        expect(d.borderRadius, BorderRadius.circular(Radii.lg));
        expect(d.border, isNull);
        final widths = [
          for (final e in find.byType(StatCard).evaluate())
            tester.getSize(find.byWidget(e.widget)).width,
        ];
        expect(widths, hasLength(3));
        expect(widths.toSet(), hasLength(1));
      },
    );
  }
}

void _coinTabTests() {
  for (final dark in [false, true]) {
    final name = dark ? '다크' : '라이트';
    testWidgets('CoinIcon 은 coin 동그라미·primary 고리·onCoin 별로 그린다 ($name)', (
      tester,
    ) async {
      final c = _c(dark);
      await _pump(tester, const CoinIcon(), dark: dark);
      expect(tester.getSize(find.byType(CoinIcon)), const Size(24, 24));
      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(CoinIcon),
          matching: find.byType(CustomPaint),
        ),
      );
      final p = paint.painter! as CoinPainter;
      expect(p.face, c.coin);
      expect(p.ring, c.primary);
      expect(p.star, c.onCoin);
    });
  }

  testWidgets('CoinIcon 은 크기를 받는다', (tester) async {
    await _pump(tester, const CoinIcon(size: 18));
    expect(tester.getSize(find.byType(CoinIcon)), const Size(18, 18));
  });

  const tabs = [
    AppTab(TabGlyph.run, '러닝'),
    AppTab(TabGlyph.history, '기록'),
    AppTab(TabGlyph.avatar, '아바타'),
    AppTab(TabGlyph.shop, '상점'),
  ];

  Future<void> pumpTabs(
    WidgetTester tester, {
    bool dark = false,
    double scale = 1,
    ValueChanged<int>? onSelected,
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? appDarkTheme() : appLightTheme(),
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(360, 640),
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            bottomNavigationBar: AppTabBar(
              tabs: tabs,
              index: 0,
              onSelected: onSelected ?? (_) {},
            ),
          ),
        ),
      ),
    );
  }

  for (final dark in [false, true]) {
    final name = dark ? '다크' : '라이트';
    testWidgets('AppTabBar 는 흰 띠, 선택 탭만 어두운 알약 ($name)', (tester) async {
      final c = _c(dark);
      await pumpTabs(tester, dark: dark);
      final bar = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(AppTabBar),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(bar.color, c.surface);

      BoxDecoration pill(String label) =>
          tester
                  .widget<AnimatedContainer>(
                    find.ancestor(
                      of: find.text(label),
                      matching: find.byType(AnimatedContainer),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      expect(pill('러닝').color, c.panel);
      expect(pill('기록').color, c.panel.withAlpha(0));
      expect(tester.widget<Text>(find.text('러닝')).style!.color, c.onPanel);
      expect(tester.widget<Text>(find.text('기록')).style!.color, c.inkMuted);

      // 아이콘은 Material 기본 세트가 아니라 앱 고유 그림이다.
      expect(find.byType(Icon), findsNothing);
      final icons = tester.widgetList<TabIcon>(find.byType(TabIcon)).toList();
      expect(icons.map((i) => i.glyph), TabGlyph.values);
      expect(icons.first.color, c.onPanel);
      expect(icons[1].color, c.inkMuted);
    });
  }

  testWidgets('AppTabBar 탭 칸은 높이 56·폭 48 이상, 누르면 그 번호를 알린다', (tester) async {
    int? picked;
    await pumpTabs(tester, onSelected: (i) => picked = i);
    for (final t in tabs) {
      final size = tester.getSize(
        find.ancestor(
          of: find.text(t.label),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(size.height, greaterThanOrEqualTo(56));
      expect(size.width, greaterThanOrEqualTo(48));
    }
    await tester.tap(find.text('상점'));
    expect(picked, 3);
  });

  for (final dark in [false, true]) {
    testWidgets('AppTabBar 가 글자 2배에서도 넘치지 않는다 (${dark ? '다크' : '라이트'})', (
      tester,
    ) async {
      await pumpTabs(tester, dark: dark, scale: 2);
      expect(tester.takeException(), isNull);
      for (final t in tabs) {
        expect(find.text(t.label), findsOneWidget);
      }
    });
  }

  testWidgets('탭 그림 4종은 서로 다르고 24 칸 안에 그린다', (tester) async {
    final paths = [for (final g in TabGlyph.values) tabGlyphPath(g)];
    for (final p in paths) {
      final b = p.getBounds();
      expect(b.isEmpty, isFalse);
      expect(b.left, greaterThanOrEqualTo(1));
      expect(b.top, greaterThanOrEqualTo(1));
      expect(b.right, lessThanOrEqualTo(23));
      expect(b.bottom, lessThanOrEqualTo(23));
    }
    final bounds = paths.map((p) => p.getBounds()).toSet();
    expect(bounds, hasLength(4));
  });
}

void _stageTests() {
  // 32×scale 정사각형 펫 자리(실제 스프라이트 대신 상자).
  Widget pet(int scale) => SizedBox(
    key: const Key('pet'),
    width: spriteFramePx * scale.toDouble(),
    height: spriteFramePx * scale.toDouble(),
  );

  test('펫 발 아래 빈 줄 수는 sprite-spec 기준점(발끝 y=29)과 같다', () {
    expect(spriteFootGapRows, spriteFramePx - 1 - 29);
  });

  for (final (scale, ground, bottom) in [
    (8, Stage.groundHeight, 32.0),
    (6, Stage.groundHeightCompact, 20.0),
  ]) {
    testWidgets('PetStage $scale배: 발끝이 무대 아래에서 땅 높이 − 8px 에 선다', (
      tester,
    ) async {
      await _pump(
        tester,
        PetStage(
          height: 300,
          scale: scale,
          groundHeight: ground,
          pet: pet(scale),
        ),
      );
      final stage = tester.getRect(find.byType(PetStage));
      final p = tester.getRect(find.byKey(const Key('pet')));
      // 시안과 같은 값: 8배는 펫 상자 아래 32, 6배는 20.
      expect(stage.bottom - p.bottom, bottom);
      final foot = p.bottom - spriteFootGapRows * scale;
      final groundTop = stage.bottom - ground;
      expect(foot - groundTop, Stage.footSink);
      expect(p.center.dx, closeTo(stage.center.dx, 0.01));
      expect(stage.height, 300);
    });
  }

  for (final (scale, ground) in [
    (8, Stage.groundHeight),
    (6, Stage.groundHeightCompact),
    (3, Stage.groundHeightMini),
  ]) {
    testWidgets('PetStage.fitHeight($scale배): 펫 상자 위끝이 무대 위끝에 닿는 높이', (
      tester,
    ) async {
      final h = PetStage.fitHeight(scale: scale, groundHeight: ground);
      final stage = PetStage(
        scale: scale,
        groundHeight: ground,
        pet: pet(scale),
      );
      expect(h, spriteFramePx * scale + stage.petBottom);
      await _pump(
        tester,
        Column(
          children: [SizedBox(height: h, child: stage)],
        ),
      );
      final s = tester.getRect(find.byType(PetStage));
      final p = tester.getRect(find.byKey(const Key('pet')));
      expect(p.top, s.top);
    });
  }

  for (final dark in [false, true]) {
    final name = dark ? '다크' : '라이트';
    testWidgets('PetStage 기본 배경: 공원 산책로 네 겹, 모서리 Stage.radius ($name)', (
      tester,
    ) async {
      await _pump(
        tester,
        PetStage(height: 300, scale: 8, pet: pet(8)),
        dark: dark,
      );
      final backdrop = tester.widget<StageBackdrop>(
        find.descendant(
          of: find.byType(PetStage),
          matching: find.byType(StageBackdrop),
        ),
      );
      expect(backdrop.scene, same(parkScene));
      expect(backdrop.scale, 8);
      expect(backdrop.feetFromBottom, Stage.groundHeight - Stage.footSink);
      expect(
        tester.getRect(find.byType(StageBackdrop)),
        tester.getRect(find.byType(PetStage)),
      );
      final clip = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byType(PetStage),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(clip.borderRadius, BorderRadius.circular(Stage.radius));
    });
  }

  testWidgets('PetStage 배경은 바꿀 수 있다(배경 아이템 자리)', (tester) async {
    const other = StageScene(
      name: 'other',
      sky: _Fill(),
      far: _Fill(),
      ground: _Fill(),
      roadside: _Fill(),
    );
    await _pump(
      tester,
      PetStage(
        height: 300,
        scale: 8,
        radius: Stage.radiusInCard,
        scene: other,
        pet: pet(8),
      ),
    );
    expect(
      tester.widget<StageBackdrop>(find.byType(StageBackdrop)).scene,
      same(other),
    );
    expect(tester.takeException(), isNull);
  });

  test('PetStage.largestScale 는 들어가는 가장 큰 정수 배율, 없으면 null', () {
    expect(
      PetStage.largestScale(max: 8, min: 3, fits: (s) => s * 32 <= 200),
      6,
    );
    expect(PetStage.largestScale(max: 8, min: 3, fits: (_) => true), 8);
    expect(PetStage.largestScale(max: 8, min: 3, fits: (s) => s <= 3), 3);
    expect(PetStage.largestScale(max: 6, min: 1, fits: (_) => false), isNull);
  });

  testWidgets('PetStage 높이를 주지 않으면 펫이 들어갈 만큼 커진다', (tester) async {
    await _pump(tester, PetStage(scale: 6, pet: pet(6)));
    final stage = tester.getRect(find.byType(PetStage));
    final p = tester.getRect(find.byKey(const Key('pet')));
    expect(p.top, greaterThanOrEqualTo(stage.top));
    expect(stage.width, 320);
  });

  for (final dark in [false, true]) {
    testWidgets(
      '말풍선은 bubble 판 + 꼬리, 글자 2배에서도 무대 안에서 넘치지 않는다 (${dark ? '다크' : '라이트'})',
      (tester) async {
        final c = _c(dark);
        await _pump(
          tester,
          PetStage(
            height: 300,
            scale: 8,
            pet: pet(8),
            bubble: const SpeechBubble('다음 레벨까지 6.0km'),
          ),
          dark: dark,
          scale: 2,
        );
        expect(tester.takeException(), isNull);
        final d = _decoration(tester, find.byType(SpeechBubble));
        // 라이트는 흰 카드, 다크는 무대 하늘보다 밝은 판(작업 12).
        expect(d.color, c.bubble);
        expect(d.borderRadius, BorderRadius.circular(Radii.md));
        expect(
          tester.widget<Text>(find.text('다음 레벨까지 6.0km')).style!.color,
          c.ink,
        );
        final stage = tester.getRect(find.byType(PetStage));
        final bubble = tester.getRect(find.byType(SpeechBubble));
        // 한 줄이라 무대가 말풍선 자리로 잡는 높이를 넘지 않는다.
        expect(
          bubble.height,
          lessThanOrEqualTo(SpeechBubble.heightFor(const TextScaler.linear(2))),
        );
        expect(stage.contains(bubble.topLeft), isTrue);
        expect(bubble.right, lessThanOrEqualTo(stage.right - Gap.s4));
      },
    );
  }
}

void _bubbleHeightTest() {
  testWidgets('SpeechBubble.heightFor 는 한 줄 말풍선 높이와 같다(1배·1.3배)', (
    tester,
  ) async {
    for (final scale in [1.0, 1.3]) {
      await _pump(tester, const SpeechBubble('Lv'), scale: scale);
      expect(
        tester.getSize(find.byType(SpeechBubble)).height,
        closeTo(SpeechBubble.heightFor(TextScaler.linear(scale)), 0.01),
      );
    }
  });
}

void _dialogTests() {
  for (final dark in [false, true]) {
    final name = dark ? '다크' : '라이트';
    testWidgets('다이얼로그: surface 판, 확인은 연두 + 경계선, 버튼은 48 이상 ($name)', (
      tester,
    ) async {
      final c = _c(dark);
      await _pump(
        tester,
        AlertDialog(
          title: const Text('기록을 지울까요?'),
          content: const Text('지운 기록은 되돌릴 수 없어요.'),
          actions: [
            TextButton(onPressed: () {}, child: const Text('취소')),
            FilledButton(onPressed: () {}, child: const Text('지우기')),
          ],
        ),
        dark: dark,
        scale: 2,
      );
      expect(tester.takeException(), isNull);
      final theme = Theme.of(tester.element(find.byType(AlertDialog)));
      expect(theme.dialogTheme.backgroundColor, c.surface);
      for (final label in ['취소', '지우기']) {
        final size = tester.getSize(
          find.ancestor(
            of: find.text(label),
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
          ),
        );
        expect(size.height, greaterThanOrEqualTo(48), reason: label);
        expect(size.width, greaterThanOrEqualTo(48), reason: label);
      }
      final filled = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(FilledButton),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(filled.color, c.primary);
      expect(
        (filled.shape! as StadiumBorder).side,
        BorderSide(color: c.primaryEdge, width: Borders.edge),
      );
      expect(filled.textStyle!.color, c.onPrimary);
    });
  }
}

void _task14Tests() {
  for (final dark in [false, true]) {
    final name = dark ? '다크' : '라이트';
    testWidgets('CircleIconButton 은 48 흰 동그라미, ink 아이콘, 이름 있는 버튼 ($name)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final c = _c(dark);
      var taps = 0;
      await _pump(
        tester,
        CircleIconButton(
          icon: Icons.chevron_left,
          label: '뒤로',
          onPressed: () => taps++,
        ),
        dark: dark,
      );
      final size = tester.getSize(find.byType(CircleIconButton));
      expect(size, const Size(48, 48));
      final d = _decoration(tester, find.byType(CircleIconButton));
      expect(d.color, c.surface);
      expect(d.shape, BoxShape.circle);
      expect(tester.widget<Icon>(find.byIcon(Icons.chevron_left)).color, c.ink);
      final data = tester
          .getSemantics(find.byType(CircleIconButton))
          .getSemanticsData();
      expect(data.label, '뒤로');
      expect(data.flagsCollection.isButton, isTrue);
      await tester.tap(find.byType(CircleIconButton));
      expect(taps, 1);
      final g = await tester.startGesture(
        tester.getCenter(find.byType(CircleIconButton)),
      );
      await tester.pump();
      expect(
        _scale(tester, find.byType(CircleIconButton)),
        Pressable.pressedScale,
      );
      await g.up();
      handle.dispose();
    });

    testWidgets('EmptyState 는 흰 카드에 그림과 inkMuted 안내 문구 ($name)', (
      tester,
    ) async {
      final c = _c(dark);
      await _pump(
        tester,
        const EmptyState(icon: CoinIcon(size: 40), message: '달리면 코인이 쌓여요'),
        dark: dark,
        scale: 1.3,
      );
      expect(tester.takeException(), isNull);
      final card = tester.widget<AppCard>(
        find.descendant(
          of: find.byType(EmptyState),
          matching: find.byType(AppCard),
        ),
      );
      expect(card.radius, Radii.lg);
      expect(find.byType(CoinIcon), findsOneWidget);
      final text = tester.widget<Text>(find.text('달리면 코인이 쌓여요'));
      expect(text.style!.color, c.inkMuted);
      expect(text.style!.fontSize, 17);
      expect(text.textAlign, TextAlign.center);
      // 그림이 문구 위에 있다.
      expect(
        tester.getRect(find.byType(CoinIcon)).bottom,
        lessThan(tester.getRect(find.text('달리면 코인이 쌓여요')).top),
      );
    });
  }

  testWidgets('작은 무대(Stage.groundHeightMini)에도 펫 발끝이 땅에 묻힌다', (tester) async {
    await _pump(
      tester,
      SizedBox(
        width: 96,
        child: PetStage(
          scale: 2,
          groundHeight: Stage.groundHeightMini,
          radius: Radii.sm,
          pet: const SizedBox.square(dimension: 64, key: Key('pet')),
        ),
      ),
    );
    final stage = tester.getRect(find.byType(PetStage));
    final pet = tester.getRect(find.byKey(const Key('pet')));
    expect(
      stage.bottom - pet.bottom,
      Stage.groundHeightMini - Stage.footSink - spriteFootGapRows * 2,
    );
    expect(
      tester.widget<StageBackdrop>(find.byType(StageBackdrop)).feetFromBottom,
      Stage.groundHeightMini - Stage.footSink,
    );
  });
}

void _task15Tests() {
  testWidgets('CircleIconButton 은 onPressed 가 null 이면 흐리고(50%) 눌리지 않는다', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const CircleIconButton(
        icon: Icons.chevron_left,
        label: '뒤로',
        onPressed: null,
      ),
    );
    final button = find.byType(CircleIconButton);
    expect(tester.getSize(button), const Size(48, 48));
    final opacity = tester.widget<Opacity>(
      find.descendant(of: button, matching: find.byType(Opacity)),
    );
    expect(opacity.opacity, 0.5);
    final data = tester.getSemantics(button).getSemanticsData();
    expect(data.label, '뒤로');
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.flagsCollection.isEnabled, Tristate.isFalse);
    final g = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    expect(_scale(tester, button), 1);
    await g.up();
    handle.dispose();
  });

  for (final dark in [false, true]) {
    final name = dark ? '다크' : '라이트';
    testWidgets('NoticeCard 는 흰 작은 카드에 danger 경계·그림·글자 ($name)', (
      tester,
    ) async {
      final c = _c(dark);
      await _pump(
        tester,
        const NoticeCard(message: '위치 신호를 받지 못하고 있어요'),
        dark: dark,
        scale: 1.3,
      );
      expect(tester.takeException(), isNull);
      final card = tester.widget<AppCard>(
        find.descendant(
          of: find.byType(NoticeCard),
          matching: find.byType(AppCard),
        ),
      );
      expect(card.radius, Radii.md);
      expect(card.borderColor, c.danger);
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(NoticeCard),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.color, c.danger);
      expect(icon.size, 24);
      final text = tester.widget<Text>(find.text('위치 신호를 받지 못하고 있어요'));
      expect(text.style!.color, c.danger);
      expect(text.style!.fontSize, 17);
      expect(text.style!.fontWeight, FontWeight.w700);
    });

    testWidgets('EmptyState.error 는 같은 카드에 inkMuted 느낌표 그림과 다시 시도 버튼 ($name)', (
      tester,
    ) async {
      final c = _c(dark);
      var retried = 0;
      await _pump(
        tester,
        EmptyState.error(
          message: '불러오지 못했어요',
          action: AppButton.secondary(
            label: '다시 시도',
            small: true,
            onPressed: () => retried++,
          ),
        ),
        dark: dark,
        scale: 1.3,
      );
      expect(tester.takeException(), isNull);
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(EmptyState),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.color, c.inkMuted, reason: '불러오기 실패는 벌주지 않게 danger 를 쓰지 않는다');
      expect(icon.size, 40);
      expect(
        tester.widget<Text>(find.text('불러오지 못했어요')).style!.color,
        c.inkMuted,
      );
      // 버튼은 문구 아래.
      expect(
        tester.getRect(find.text('불러오지 못했어요')).bottom,
        lessThan(tester.getRect(find.byType(AppButton)).top),
      );
      await tester.tap(find.text('다시 시도'));
      expect(retried, 1);
    });
  }
}

/// 무대 전체를 하늘색으로 칠하는 겹(배경 바꾸기 테스트용).
class _Fill extends StageLayer {
  const _Fill();

  @override
  void paintStill(StagePixels px, StageView v) => px.fill(v.colors.surface);
}
