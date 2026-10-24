import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../avatar/app/providers.dart';
import '../../avatar/domain/avatar_name.dart';
import '../../avatar/domain/growth_rules.dart';
import '../../avatar/ui/avatar_view.dart';
import '../../avatar/ui/sprite_sheet.dart' show spriteFramePx;
import '../../core/korean.dart';
import '../../core/theme.dart';
import '../../core/ui/components.dart';
import '../../profile/app/providers.dart';

/// 저장소의 기본 이름. 이 이름이면 아직 이름을 짓지 않은 것으로 보고 종류별 추천 이름을 채운다.
const _defaultAvatarName = '러니';

/// 1장 제목. 종류마다 1단계 이름과 조사가 달라 문장째로 둔다.
String _headline(AvatarKind kind) => switch (kind) {
  AvatarKind.chick => '병아리 알이 왔어요!',
  AvatarKind.jelly => '젤리 새싹이 왔어요!',
  AvatarKind.acorn => '꼬마 도토리가 왔어요!',
};

/// 종류별 추천 이름.
String _suggestedName(AvatarKind kind) => switch (kind) {
  AvatarKind.chick => '삐약이',
  AvatarKind.jelly => '말랑이',
  AvatarKind.acorn => '토리',
};

const _pageCount = 2;

/// 첫 실행 화면: 1 캐릭터 소개 → 2 이름 짓기.
/// 시작하기를 누르면 이름을 저장하고 완료를 표시한 뒤 [onFinished] 를 부른다.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Loaded {
  const _Loaded(this.kind);
  final AvatarKind kind;
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _name = TextEditingController();
  late Future<_Loaded> _load;
  int _page = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load = _read();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<_Loaded> _read() async {
    final repo = ref.read(growthRepositoryProvider);
    final kind = await repo.avatarKind();
    final name = await repo.avatarName();
    _name.text = name == _defaultAvatarName ? _suggestedName(kind) : name;
    return _Loaded(kind);
  }

  String get _trimmedName => _name.text.trim();
  String? get _nameError => validateAvatarName(_name.text);

  void _go(int page) {
    // 저장 중에는 장을 바꾸지 않는다(끝나면 onFinished 가 불린다).
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() => _page = page);
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(growthRepositoryProvider).setAvatarName(_trimmedName);
      await ref.read(profileRepositoryProvider).markOnboarded();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('저장하지 못했어요')));
      return;
    }
    if (!mounted) return;
    ref.invalidate(growthStateProvider);
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 1장에서는 기본 동작(앱 나가기), 2장에서는 앞 장으로. 저장 중에는 막는다.
      canPop: _page == 0 && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _page > 0 && !_saving) _go(_page - 1);
      },
      child: Scaffold(
        body: SafeArea(
          child: FutureBuilder<_Loaded>(
            future: _load,
            builder: (context, snap) {
              if (snap.hasError) return _LoadError(onRetry: _retry);
              final data = snap.data;
              if (data == null) return const SizedBox.shrink();
              return _body(context, data);
            },
          ),
        ),
      ),
    );
  }

  void _retry() => setState(() => _load = _read());

  Widget _body(BuildContext context, _Loaded data) {
    final page = switch (_page) {
      0 => _IntroPage(kind: data.kind),
      _ => _NamePage(
        kind: data.kind,
        controller: _name,
        error: _nameError,
        onSubmitted: () {
          if (_nameError == null) _finish();
        },
      ),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.s5, Gap.s6, Gap.s5, Gap.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Dots(index: _page, count: _pageCount),
          const SizedBox(height: Gap.s5),
          Expanded(
            // 장 넘김은 화면 전환과 같은 시간(들어오기 enter, 나가기 exit)의 교차 페이드.
            child: AnimatedSwitcher(
              duration: Motion.of(context, Motion.enter),
              reverseDuration: Motion.of(context, Motion.exit),
              switchInCurve: Motion.enterCurve,
              switchOutCurve: Motion.exitCurve,
              child: KeyedSubtree(key: ValueKey(_page), child: page),
            ),
          ),
          const SizedBox(height: Gap.s5),
          _buttons(context),
        ],
      ),
    );
  }

  Widget _buttons(BuildContext context) {
    final nextButton = switch (_page) {
      0 => AppButton(label: '다음', onPressed: () => _go(1)),
      _ => AppButton(
        label: '시작하기',
        onPressed: _saving || _nameError != null ? null : _finish,
      ),
    };
    if (_page == 0) return nextButton;
    return Row(
      children: [
        SizedBox(
          width: 112,
          child: AppButton.secondary(
            label: '이전',
            onPressed: _saving ? null : () => _go(_page - 1),
          ),
        ),
        const SizedBox(width: Gap.s3),
        Expanded(child: nextButton),
      ],
    );
  }
}

/// 진행 점. 지금 장은 넓은 primary-deep 알약, 나머지는 line-strong 점(둘 다 바탕과 3:1).
class _Dots extends StatelessWidget {
  const _Dots({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      label: '$count단계 중 ${index + 1}단계',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: Gap.s2),
            AnimatedContainer(
              duration: Motion.of(context, Motion.quick),
              curve: Motion.standard,
              width: i == index ? 28 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index ? c.primaryDeep : c.lineStrong,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 남은 높이를 채우고, 모자라면 스크롤되는 장 틀.
class _PageScroll extends StatelessWidget {
  const _PageScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [SliverFillRemaining(hasScrollBody: false, child: child)],
    );
  }
}

/// 첫 실행 무대: 남은 높이를 채우는 사각 무대에 마스코트(1단계)를 들어가는 가장 큰 정수
/// 배율로 세운다(8배까지, 3배 아래로는 줄이지 않고 장이 스크롤한다). [bubble] 은 오른쪽 위
/// 말풍선이고, 펫 그림을 가리지 않게(프레임 위 빈 줄까지만 겹치게) 자리를 늘 잡아 둔다.
/// 그래서 말풍선이 사라져도 무대 높이·배율은 그대로다.
class _FillStage extends StatelessWidget {
  const _FillStage({
    required this.stageKey,
    required this.kind,
    this.withBubble = false,
    this.bubble,
  });

  final Key stageKey;
  final AvatarKind kind;

  /// 말풍선 자리를 잡는다.
  final bool withBubble;

  /// 말풍선 문구. null 이면 자리만 두고 그리지 않는다.
  final String? bubble;

  static const int _maxScale = 8;
  static const int _minScale = 3;

  /// [scale] 배 펫(과 말풍선)이 서는 무대 높이.
  double _needed(int scale, double bubbleHeight) {
    final pet =
        spriteFramePx * scale +
        Stage.groundHeight -
        Stage.footSink -
        spriteFootGapRows * scale;
    final top = withBubble
        ? Gap.s4 + bubbleHeight - spriteTopGapRows * scale
        : Gap.s6;
    return pet + math.max(0, top);
  }

  @override
  Widget build(BuildContext context) {
    final bubbleHeight = SpeechBubble.heightFor(
      MediaQuery.textScalerOf(context),
    );
    return MinIntrinsicHeight(
      height: _needed(_minScale, bubbleHeight),
      child: LayoutBuilder(
        builder: (context, box) {
          final scale =
              PetStage.largestScale(
                max: _maxScale,
                min: _minScale,
                fits: (s) =>
                    _needed(s, bubbleHeight) <= box.maxHeight &&
                    spriteFramePx * s + 2 * Gap.s4 <= box.maxWidth,
              ) ??
              _minScale;
          return PetStage(
            key: stageKey,
            height: box.maxHeight,
            scale: scale,
            pet: ExcludeSemantics(
              child: AvatarView(
                kind: kind,
                stage: 1,
                mood: AvatarMood.normal,
                action: AvatarAction.idle,
                scale: scale,
              ),
            ),
            // 입력칸이 이미 읽히므로 이름 말풍선은 스크린 리더에서 뺀다.
            bubble: bubble == null
                ? null
                : ExcludeSemantics(child: SpeechBubble(bubble!)),
          );
        },
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({required this.kind});

  final AvatarKind kind;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    return _PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '처음 만나는 러닝 친구',
            textAlign: TextAlign.center,
            style: t.label.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: Gap.s3),
          Expanded(
            child: _FillStage(
              stageKey: const ValueKey('onboarding-stage'),
              kind: kind,
            ),
          ),
          const SizedBox(height: Gap.s5),
          Semantics(
            header: true,
            child: _KeepAllText(
              _headline(kind),
              textAlign: TextAlign.center,
              style: t.title,
            ),
          ),
          const SizedBox(height: Gap.s2),
          Center(
            child: _MaxWidth(
              300,
              child: _KeepAllText(
                '달린 거리만큼 자라서 러닝화를 신고, 언젠가 마라토너가 돼요.',
                textAlign: TextAlign.center,
                style: t.body.copyWith(color: c.inkMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NamePage extends StatelessWidget {
  const _NamePage({
    required this.kind,
    required this.controller,
    required this.error,
    required this.onSubmitted,
  });

  final AvatarKind kind;
  final TextEditingController controller;
  final String? error;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    final name = controller.text.trim();
    return _PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ScreenTitle('이름을 지어 주세요'),
          const SizedBox(height: Gap.s2),
          _KeepAllText(
            '홈과 아바타 탭에서 이 이름으로 불러요. 설정에서 바꿀 수 있어요.',
            style: t.body.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: Gap.s5),
          // 마스코트가 지금 이름을 말풍선으로 단다. 키보드가 올라오면 무대가 줄어든다.
          Expanded(
            child: _FillStage(
              stageKey: const ValueKey('onboarding-name-stage'),
              kind: kind,
              withBubble: true,
              bubble: name.isEmpty ? null : name,
            ),
          ),
          const SizedBox(height: Gap.s5),
          ExcludeSemantics(child: Text('이름', style: t.heading)),
          const SizedBox(height: Gap.s2),
          Semantics(
            label: '이름',
            child: TextField(
              controller: controller,
              style: t.body,
              textInputAction: TextInputAction.done,
              // 넘게 쳐도 막지 않고 안내한다(오류 문구 + 다음 막기).
              maxLengthEnforcement: MaxLengthEnforcement.none,
              inputFormatters: [
                // 줄바꿈은 받지 않는다.
                FilteringTextInputFormatter.deny(RegExp(r'[\n\r]')),
              ],
              onSubmitted: (_) => onSubmitted(),
              // 모양은 테마(inputDecorationTheme). 글자 수는 넘치면 danger.
              decoration: InputDecoration(
                helperText: '1~$avatarNameMaxLength자',
                errorText: error,
                counterText: '${name.runes.length}/$avatarNameMaxLength',
                counterStyle: error == null
                    ? null
                    : t.caption.copyWith(color: c.danger),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Gap.s5),
      child: Center(
        child: SingleChildScrollView(
          child: EmptyState.error(
            message: '불러오지 못했어요',
            action: AppButton(label: '다시 시도', onPressed: onRetry),
          ),
        ),
      ),
    );
  }
}

/// 띄어쓰기에서만 줄을 바꾸는 글자([keepAll]). 스크린 리더는 원문을 읽는다.
class _KeepAllText extends StatelessWidget {
  const _KeepAllText(this.text, {required this.style, this.textAlign});

  final String text;
  final TextStyle style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Text(
    keepAll(text),
    semanticsLabel: text,
    style: style,
    textAlign: textAlign,
  );
}

/// 폭 상한. [ConstrainedBox] 는 고유 높이를 잴 때 maxWidth 를 무시해, 넓은 화면에서
/// [SliverFillRemaining] 이 글자 줄 수를 실제보다 적게 잡고 무대가 넘친다.
/// 고유 높이도 상한 폭으로 잰다.
class _MaxWidth extends SingleChildRenderObjectWidget {
  const _MaxWidth(this.maxWidth, {required Widget super.child});

  final double maxWidth;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMaxWidth(maxWidth);

  @override
  void updateRenderObject(BuildContext context, _RenderMaxWidth renderObject) {
    renderObject.additionalConstraints = BoxConstraints(maxWidth: maxWidth);
  }
}

class _RenderMaxWidth extends RenderConstrainedBox {
  _RenderMaxWidth(double maxWidth)
    : super(additionalConstraints: BoxConstraints(maxWidth: maxWidth));

  double _clamp(double width) =>
      math.min(width, additionalConstraints.maxWidth);

  @override
  double computeMinIntrinsicHeight(double width) =>
      super.computeMinIntrinsicHeight(_clamp(width));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      super.computeMaxIntrinsicHeight(_clamp(width));
}
