import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../avatar/app/providers.dart';
import '../../avatar/domain/avatar_name.dart';
import '../../avatar/domain/growth_rules.dart';
import '../../avatar/ui/avatar_view.dart';
import '../../avatar/ui/weekly_goal_bar.dart';
import '../../core/korean.dart';
import '../../core/theme.dart';
import '../../core/ui/clay.dart';
import '../../core/week.dart';
import '../../profile/app/providers.dart';
import '../../run/app/providers.dart';

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

/// 3장 목표 카드(km, 설명).
const _goals = [(3, '첫걸음'), (5, '가볍게'), (10, '추천'), (15, '꾸준히'), (20, '도전')];

const _pageCount = 3;

/// 첫 실행 화면: 1 캐릭터 소개 → 2 이름 짓기 → 3 주간 목표.
/// 시작하기를 누르면 이름·목표를 저장하고 완료를 표시한 뒤 [onFinished] 를 부른다.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Loaded {
  const _Loaded(this.kind, this.targetKm);
  final AvatarKind kind;

  /// 지금 목표가 다섯 카드 중 하나면 그 km, 아니면 null.
  final int? targetKm;
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _name = TextEditingController();
  late Future<_Loaded> _load;
  int _page = 0;
  int? _goalKm;
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
    final targetM = await repo.weeklyTarget(
      weekStartOf(ref.read(clockProvider)()),
    );
    final targetKm = _goals
        .map((g) => g.$1)
        .where((km) => km * 1000 == targetM)
        .firstOrNull;
    _name.text = name == _defaultAvatarName ? _suggestedName(kind) : name;
    _goalKm = targetKm;
    return _Loaded(kind, targetKm);
  }

  String get _trimmedName => _name.text.trim();
  String? get _nameError => validateAvatarName(_name.text);

  void _go(int page) {
    FocusScope.of(context).unfocus();
    setState(() => _page = page);
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    final km = _goalKm;
    try {
      await ref.read(growthRepositoryProvider).setAvatarName(_trimmedName);
      if (km != null) {
        await ref.read(growthServiceProvider).setWeeklyTarget(km * 1000.0);
      }
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
      // 1장에서는 기본 동작(앱 나가기), 2·3장에서는 앞 장으로.
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _page > 0) _go(_page - 1);
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
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final page = switch (_page) {
      0 => _IntroPage(kind: data.kind),
      1 => _NamePage(
        kind: data.kind,
        controller: _name,
        error: _nameError,
        onSubmitted: () {
          if (_nameError == null) _go(2);
        },
      ),
      _ => _GoalPage(
        name: _trimmedName,
        selectedKm: _goalKm,
        onSelected: (km) => setState(() => _goalKm = km),
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
            child: AnimatedSwitcher(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
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
      0 => ClayButton(label: '다음', onPressed: () => _go(1)),
      1 => ClayButton(
        label: '다음',
        onPressed: _nameError == null ? () => _go(2) : null,
      ),
      _ => ClayButton(label: '시작하기', onPressed: _saving ? null : _finish),
    };
    if (_page == 0) return nextButton;
    return Row(
      children: [
        SizedBox(
          width: 112,
          child: ClayButton.secondary(
            context,
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

/// 진행 점. 지금 장은 넓은 primary 알약, 나머지는 line 점.
class _Dots extends StatelessWidget {
  const _Dots({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Semantics(
      label: '$count단계 중 ${index + 1}단계',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: Gap.s2),
            AnimatedContainer(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              width: i == index ? 28 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index ? c.primary : c.line,
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

/// 무대: surface-soft 바탕, line 테두리, 안쪽 아래 립 느낌의 line 띠.
class _Stage extends StatelessWidget {
  const _Stage({required this.child, this.padding = Gap.s6});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceSoft,
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border(
          top: BorderSide(color: c.line, width: Borders.thick),
          left: BorderSide(color: c.line, width: Borders.thick),
          right: BorderSide(color: c.line, width: Borders.thick),
          bottom: BorderSide(
            color: c.line,
            width: Borders.thick + Borders.lip + 2,
          ),
        ),
      ),
      child: Padding(padding: EdgeInsets.all(padding), child: child),
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
          const SizedBox(height: Gap.s5),
          Expanded(
            child: _Stage(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ExcludeSemantics(
                    child: AvatarView(
                      kind: kind,
                      stage: 1,
                      mood: AvatarMood.normal,
                      action: AvatarAction.idle,
                      scale: 4,
                    ),
                  ),
                  const SizedBox(height: Gap.s4),
                  Semantics(
                    header: true,
                    child: _KeepAllText(
                      _headline(kind),
                      textAlign: TextAlign.center,
                      style: t.title,
                    ),
                  ),
                  const SizedBox(height: Gap.s4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: _KeepAllText(
                      '달린 거리만큼 자라서 러닝화를 신고, 언젠가 마라토너가 돼요.',
                      textAlign: TextAlign.center,
                      style: t.body,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Gap.s5),
          ClayCard(
            radius: Radii.md,
            padding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: Gap.s4,
            ),
            child: MergeSemantics(
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.directions_walk,
                      size: 28,
                      color: c.primaryDeep,
                    ),
                  ),
                  const SizedBox(width: Gap.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('걷다 뛰다 OK', style: t.bodyStrong),
                        const SizedBox(height: 2),
                        _KeepAllText(
                          '빨리 달리지 않아도 움직인 만큼 자라요.',
                          style: t.caption.copyWith(color: c.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ],
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
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.sm),
      borderSide: BorderSide(color: color, width: Borders.thick),
    );
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
          _Stage(
            padding: Gap.s5,
            child: Column(
              children: [
                ExcludeSemantics(
                  child: AvatarView(
                    kind: kind,
                    stage: 1,
                    mood: AvatarMood.normal,
                    action: AvatarAction.idle,
                    scale: 3,
                  ),
                ),
                const SizedBox(height: Gap.s2),
                // 입력칸이 이미 읽히므로 미리보기는 스크린 리더에서 뺀다.
                ExcludeSemantics(
                  child: Text(
                    name.isEmpty ? ' ' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: t.titleS,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.s5),
          ExcludeSemantics(child: Text('이름', style: t.label)),
          const SizedBox(height: Gap.s2),
          Semantics(
            label: '이름',
            child: TextField(
              controller: controller,
              style: t.body,
              textInputAction: TextInputAction.next,
              // 넘게 쳐도 막지 않고 안내한다(오류 문구 + 다음 막기).
              maxLengthEnforcement: MaxLengthEnforcement.none,
              inputFormatters: [
                // 줄바꿈은 받지 않는다.
                FilteringTextInputFormatter.deny(RegExp(r'[\n\r]')),
              ],
              onSubmitted: (_) => onSubmitted(),
              decoration: InputDecoration(
                filled: true,
                fillColor: c.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Gap.s4,
                  vertical: Gap.s4,
                ),
                enabledBorder: border(c.line),
                focusedBorder: border(c.primary),
                errorBorder: border(c.danger),
                focusedErrorBorder: border(c.danger),
                helperText: '1~$avatarNameMaxLength자',
                helperStyle: t.caption.copyWith(color: c.inkMuted),
                errorText: error,
                errorStyle: t.caption.copyWith(color: c.danger),
                counterText: '${name.runes.length}/$avatarNameMaxLength',
                counterStyle: t.caption.copyWith(
                  color: error == null ? c.inkMuted : c.danger,
                ),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _GoalPage extends StatelessWidget {
  const _GoalPage({
    required this.name,
    required this.selectedKm,
    required this.onSelected,
  });

  final String name;
  final int? selectedKm;
  final ValueChanged<int> onSelected;

  Widget _cell(int i) {
    if (i >= _goals.length) return const SizedBox.shrink();
    final (km, sub) = _goals[i];
    return _GoalCard(
      km: km,
      sublabel: sub,
      selected: km == selectedKm,
      onTap: () => onSelected(km),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    return _PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ScreenTitle('이번 주 목표를 정해요'),
          const SizedBox(height: Gap.s2),
          _KeepAllText(
            '목표를 채우면 $name${subjectParticle(name)} 경험치 +$weeklyGoalBonusXp 을 받아요. '
            '매일 달리지 않아도 돼요.',
            style: t.body.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: Gap.s5),
          // 3열 격자. 남는 칸은 빈 자리로 채워 폭을 맞춘다.
          Semantics(
            label: '주간 목표',
            container: true,
            explicitChildNodes: true,
            child: Column(
              children: [
                for (var row = 0; row * 3 < _goals.length; row++) ...[
                  if (row > 0) const SizedBox(height: Gap.s3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var col = 0; col < 3; col++) ...[
                        if (col > 0) const SizedBox(width: Gap.s3),
                        Expanded(child: _cell(row * 3 + col)),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Gap.s4),
          _KeepAllText(
            '10km 는 주 3번 3km 남짓이에요. 목표는 홈과 설정에서 언제든 바꿀 수 있어요'
            '(최소 ${weeklyTargetMinKm}km).',
            style: t.caption.copyWith(color: c.inkMuted),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

/// 목표 선택 카드. 라디오처럼 읽히고(하나만 고름), 누르면 립만큼 내려앉는다.
class _GoalCard extends StatefulWidget {
  const _GoalCard({
    required this.km,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });

  final int km;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<_GoalCard> {
  bool _pressed = false;
  bool _focused = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    final selected = widget.selected;
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: true,
      label: '${widget.km}km, ${widget.sublabel}',
      excludeSemantics: true,
      onTap: widget.onTap,
      child: FocusableActionDetector(
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _set(true),
          onTapUp: (_) => _set(false),
          onTapCancel: () => _set(false),
          onTap: widget.onTap,
          child: ClayPress(
            pressed: _pressed,
            builder: (context, lip) => ClayCard(
              reserveLip: false,
              lipHeight: lip,
              radius: Radii.md,
              color: selected ? c.surfaceSoft : c.surface,
              borderColor: _focused
                  ? c.primaryDeep
                  : (selected ? c.primary : c.line),
              lipColor: selected ? c.primaryDeep : c.lineStrong,
              padding: const EdgeInsets.symmetric(
                vertical: Gap.s2,
                horizontal: Gap.s1,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 70),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('${widget.km}km', style: t.stat),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.sublabel,
                        style: t.caption.copyWith(
                          color: selected ? c.primaryDeep : c.inkMuted,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontVariations: [
                            FontVariation('wght', selected ? 700 : 500),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '불러오지 못했어요',
            textAlign: TextAlign.center,
            style: AppText.of(context).body,
          ),
          const SizedBox(height: Gap.s4),
          ClayButton(label: '다시 시도', onPressed: onRetry),
        ],
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
