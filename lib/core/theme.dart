import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

/// 디자인 값(색·글자·간격·모서리·움직임)의 유일한 출처. 기준: docs/design/tokens.json
/// 방향: 연두 무드보드(결정 0029). 화면 코드는 `Color(0x…)`·`Colors.xxx` 대신 아래 토큰만 읽는다.
///
/// 사용법
/// - 색: `AppColors.of(context)`
/// - 글자: `AppText.of(context).distanceXl` (색은 ink, 바꾸려면 copyWith(color:))
/// - 간격·모서리·테두리: `Gap.s4`, `Radii.lg`, `Borders.edge`
/// - 사각 무대 치수: `Stage.groundHeight`, 움직임: `Motion.enter`, `Motion.enterCurve`

/// 간격 토큰. `sN` 은 tokens.json 의 `space-N`.
class Gap {
  Gap._();
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;

  /// 섹션 사이.
  static const double s7 = 28;
  static const double s8 = 32;
}

/// 모서리 토큰.
class Radii {
  Radii._();
  static const double sm = 12;

  /// 작은 카드, 말풍선, 카드 안 무대.
  static const double md = 20;

  /// 카드, 무대, 다이얼로그.
  static const double lg = 24;

  /// 마스코트 판 카드(요약 레벨 업).
  static const double xl = 28;
  static const double pill = 999;
}

/// 선 두께.
class Borders {
  Borders._();

  /// 선택 카드 윤곽(primaryEdge)·입력칸·스위치(lineStrong) 경계선. 바탕 대비 3:1 을 이 선이 맡는다.
  /// 연두 버튼·칩 면과 흰 보조 버튼에는 두르지 않는다(작업 31, 옅은 플로팅 그림자로 뜬다).
  static const double edge = 2;

  /// 흰 보조 버튼의 머리카락 선(line 계열, 진하지 않게). 흰 면이 바탕과 구분되도록 돕는다(작업 31).
  static const double hairline = 1;

  /// 땅 띠 윗선(stageGroundLine). 앱 아이콘 무대가 쓴다(앱 안 무대는 작업 25 부터 공원 산책로 배경).
  static const double groundLine = 4;

  /// 키보드 포커스 윤곽(primaryDeep).
  static const double focus = 3;
}

/// 사각 무대(마스코트 뒤 배경 네 겹) 치수. 색은 [AppColors.stageSky] 등.
/// 배경 그림은 `lib/core/stage/` 의 `StageScene`(기본 공원 산책로)이고, 배경 아이템은 겹 단위로 바꾼다.
class Stage {
  Stage._();

  /// 화면 폭 무대 모서리.
  static const double radius = Radii.lg;

  /// 카드 안 무대 모서리.
  static const double radiusInCard = Radii.md;

  /// 땅 높이(발끝 기준, 옛 땅 띠). 홈·요약(8배 캐릭터): 발끝이 무대 아래 48.
  static const double groundHeight = 56;

  /// 땅 높이(발끝 기준). 러닝 중(6배 캐릭터): 발끝이 무대 아래 32.
  static const double groundHeightCompact = 40;

  /// 땅 높이(발끝 기준). 카드 안 작은 무대(상점 아이템·성장 단계, 2~3배 캐릭터): 발끝이 무대 아래 16.
  static const double groundHeightMini = 24;

  /// 발끝 기준: 발끝은 무대 아래에서 (땅 높이 − 이 값) 위에 선다(옛 땅 띠 윗선 아래 8px 자리).
  static const double footSink = 8;
}

/// 움직임 토큰. 들어올 때 감속, 나갈 때 가속, 나가기는 들어오기의 약 2/3.
/// 시스템 "애니메이션 줄이기" 를 켜면 움직임을 빼고 바로 최종 상태를 보인다:
/// 시간은 [Motion.of] 로 읽고, 컨트롤러로 돌리는 연출은 [Motion.reduced] 면 끝 값에 둔다.
class Motion {
  Motion._();

  /// 누름 반응(눌림·되돌아옴).
  static const press = Duration(milliseconds: 80);

  /// 선택 바뀜(칩·분할·탭), 작은 상태 변화.
  static const quick = Duration(milliseconds: 160);

  /// 화면·시트가 들어올 때.
  static const enter = Duration(milliseconds: 300);

  /// 화면·시트가 나갈 때.
  static const exit = Duration(milliseconds: 200);

  /// 레벨 업·배지 획득 같은 보상 연출.
  static const celebrate = Duration(milliseconds: 600);

  /// 제자리 상태 변화.
  static const Curve standard = Curves.easeInOutCubic;

  /// 들어오기(감속).
  static const Curve enterCurve = Curves.easeOutCubic;

  /// 나가기(가속).
  static const Curve exitCurve = Curves.easeInCubic;

  /// 보상 튀어 오름(끝에서 살짝 넘침).
  static const Curve pop = Curves.easeOutBack;

  /// 시스템 "애니메이션 줄이기"(`MediaQuery.disableAnimations`)가 켜져 있는가.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration] 그대로, 애니메이션 줄이기면 0(바로 최종 상태).
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;

  /// 아래 시트(`showModalBottomSheet` 의 `sheetAnimationStyle`): [enter]·[enterCurve] 로
  /// 올라오고 [exit]·[exitCurve] 로 내려간다. 애니메이션 줄이기면 바로 열리고 닫힌다.
  static AnimationStyle sheet(BuildContext context) =>
      sheetStyle(reduced: reduced(context));

  /// [sheet] 의 값. [reduced] 면 시간 0.
  static AnimationStyle sheetStyle({required bool reduced}) => AnimationStyle(
    duration: reduced ? Duration.zero : enter,
    reverseDuration: reduced ? Duration.zero : exit,
    curve: enterCurve,
    reverseCurve: exitCurve,
  );
}

/// 앱 화면 전환(Android): 들어오는 화면이 [Motion.enter] 동안 살짝 아래에서 올라오며
/// 나타나고([Motion.enterCurve]), 나갈 때는 [Motion.exit] 동안 거꾸로([Motion.exitCurve]).
/// 애니메이션 줄이기면 전환 없이 바로 새 화면을 보인다.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  /// 들어오는 화면이 올라오는 거리(화면 높이 비율).
  static const double rise = 0.04;

  @override
  Duration get transitionDuration => Motion.enter;

  @override
  Duration get reverseTransitionDuration => Motion.exit;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (Motion.reduced(context)) return child;
    return _RiseTransition(animation: animation, child: child);
  }
}

class _RiseTransition extends StatefulWidget {
  const _RiseTransition({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  State<_RiseTransition> createState() => _RiseTransitionState();
}

class _RiseTransitionState extends State<_RiseTransition> {
  late CurvedAnimation _curve = _curved();
  late Animation<Offset> _offset = _rise();

  CurvedAnimation _curved() => CurvedAnimation(
    parent: widget.animation,
    curve: Motion.enterCurve,
    reverseCurve: Motion.exitCurve,
  );

  Animation<Offset> _rise() => Tween(
    begin: const Offset(0, AppPageTransitionsBuilder.rise),
    end: Offset.zero,
  ).animate(_curve);

  @override
  void didUpdateWidget(_RiseTransition old) {
    super.didUpdateWidget(old);
    if (old.animation != widget.animation) {
      _curve.dispose();
      _curve = _curved();
      _offset = _rise();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _curve,
    child: SlideTransition(position: _offset, child: widget.child),
  );
}

/// Material ColorScheme 슬롯이 없는 토큰까지 모두 담은 색 확장.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceSoft,
    required this.line,
    required this.lineStrong,
    required this.ink,
    required this.inkMuted,
    required this.primary,
    required this.onPrimary,
    required this.primaryEdge,
    required this.primaryDeep,
    required this.panel,
    required this.onPanel,
    required this.stageInk,
    required this.coin,
    required this.onCoin,
    required this.success,
    required this.danger,
    required this.stageSky,
    required this.stageGround,
    required this.stageGroundLine,
    required this.paceSlow,
    required this.paceMid,
    required this.paceFast,
    required this.spriteRim,
    required this.bubble,
    required this.floatShadow,
  });

  /// 화면 바탕(옅은 풀빛). 무늬·그라데이션 없음.
  final Color background;

  /// 카드·다이얼로그·탭바. 테두리 없이 바탕과 톤 차이로 떨어진다.
  final Color surface;

  /// 트랙: 진행 막대 빈 부분, 선택 안 된 칩, 분할 선택 바탕.
  final Color surfaceSoft;

  /// 옅은 구분선.
  final Color line;

  /// 입력칸·스위치(꺼짐)·진행 점 테두리. 바탕·카드·트랙 대비 3:1 이상. 흰 보조 버튼에는 쓰지 않는다.
  final Color lineStrong;

  final Color ink;
  final Color inkMuted;

  /// 연두: 누를 것(주요 버튼)·선택된 칩. 그림·막대 채움에는 쓰지 않는다.
  final Color primary;
  final Color onPrimary;

  /// 윤곽 연두: 고른 카드 윤곽, 경로 시작 점·스플래시 타일 테두리.
  /// 연두 버튼·칩·스위치 면에는 두르지 않는다(작업 31, 면은 [floatShadow] 로 뜬다).
  final Color primaryEdge;

  /// 초록: 강조 글자, 경험치 +, 진행 막대·구간 막대 채움, 한 색 경로 선, 글자 버튼.
  final Color primaryDeep;

  /// 어두운 판: 일시정지 버튼, 탭바 선택 알약. 다크에서는 밝은 판.
  final Color panel;
  final Color onPanel;

  /// 무대(stageSky) 위 글자, 무대색 알약 위 글자.
  final Color stageInk;

  /// 코인 글자·코인 그림 바탕.
  final Color coin;

  /// 코인 그림 안 별.
  final Color onCoin;

  /// 목표 달성.
  final Color success;
  final Color danger;

  /// 사각 무대 하늘 겹(배경 1).
  final Color stageSky;

  /// 사각 무대 풀밭(배경 3 땅·길의 길 밖 바닥 면).
  final Color stageGround;

  /// 풀밭 풀잎 점, 앱 아이콘 땅 윗선([Borders.groundLine]).
  final Color stageGroundLine;

  /// 경로 페이스 3단(천천히·보통·빠르게): 연두 한 계열의 명도 단계(라이트는 빠를수록 짙게,
  /// 다크는 빠를수록 옅게). 적·녹·청 색각 이상과 빠른 이동(ink-muted) 사이에서도
  /// CIEDE2000 15 이상 떨어진다(theme_test).
  final Color paceSlow;
  final Color paceMid;
  final Color paceFast;

  /// 스프라이트 둘레 1픽셀 윤곽. 투명이면 그리지 않는다 (라이트).
  final Color spriteRim;

  /// 무대 위 말풍선 판. 라이트는 surface 와 같은 흰색, 다크는 무대 하늘보다 밝은 판
  /// (다크 surface 는 하늘과 톤이 같아 말풍선 모양·꼬리가 묻힌다). 위 글자는 ink.
  final Color bubble;

  /// 버튼·선택된 칩이 면 경계선 없이 뜨는 옅은 그림자(elevation-float, 작업 31).
  /// 라이트는 ink 계열 8~14%, 다크는 어두운 바탕에서 거의 안 보이는 검정 20%.
  final List<BoxShadow> floatShadow;

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  /// 모든 토큰(순서 고정). 값 비교·해시에 쓴다.
  List<Color> get _values => [
    background,
    surface,
    surfaceSoft,
    line,
    lineStrong,
    ink,
    inkMuted,
    primary,
    onPrimary,
    primaryEdge,
    primaryDeep,
    panel,
    onPanel,
    stageInk,
    coin,
    onCoin,
    success,
    danger,
    stageSky,
    stageGround,
    stageGroundLine,
    paceSlow,
    paceMid,
    paceFast,
    spriteRim,
    bubble,
  ];

  /// 값이 같으면 같다. 테마 lerp·copyWith 로 새로 만든 같은 색 묶음도 같게 본다
  /// (무대 배경 그림 캐시가 이 값으로 키를 잡는다, 작업 25).
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppColors &&
          listEquals(other._values, _values) &&
          listEquals(other.floatShadow, floatShadow);

  @override
  int get hashCode => Object.hashAll([..._values, ...floatShadow]);

  static const light = AppColors(
    background: Color(0xFFF3F5EE),
    surface: Color(0xFFFFFFFF),
    surfaceSoft: Color(0xFFE8ECE2),
    line: Color(0xFFDDE3D4),
    lineStrong: Color(0xFF737D6A),
    ink: Color(0xFF16200F),
    inkMuted: Color(0xFF5B6357),
    primary: Color(0xFFB8F04A),
    onPrimary: Color(0xFF14210A),
    primaryEdge: Color(0xFF4F8A16),
    primaryDeep: Color(0xFF1E7B45),
    panel: Color(0xFF16200F),
    onPanel: Color(0xFFFFFFFF),
    stageInk: Color(0xFF0E5E33),
    coin: Color(0xFF1E40AF),
    onCoin: Color(0xFFFFFFFF),
    success: Color(0xFF1E7B45),
    danger: Color(0xFFB91C1C),
    stageSky: Color(0xFFE3F6C8),
    stageGround: Color(0xFFCDEBA8),
    stageGroundLine: Color(0xFFB3DB82),
    paceSlow: Color(0xFF659325),
    paceMid: Color(0xFF066B0E),
    paceFast: Color(0xFF003647),
    spriteRim: Color(0x00000000),
    bubble: Color(0xFFFFFFFF),
    // elevation-float 라이트: ink(#16200F) 14% 큰 그림자 + 8% 맞닿는 그림자. 비교 C 안(38%·22%)의 약 3분의 1.
    floatShadow: [
      BoxShadow(
        color: Color(0x2416200F),
        offset: Offset(0, 3),
        blurRadius: 8,
        spreadRadius: -3,
      ),
      BoxShadow(color: Color(0x1416200F), offset: Offset(0, 1), blurRadius: 2),
    ],
  );

  static const dark = AppColors(
    background: Color(0xFF10160D),
    surface: Color(0xFF1A2316),
    surfaceSoft: Color(0xFF28331F),
    line: Color(0xFF2E3A28),
    lineStrong: Color(0xFF7F8B74),
    ink: Color(0xFFEEF4E6),
    inkMuted: Color(0xFFA3AE99),
    primary: Color(0xFFB8F04A),
    onPrimary: Color(0xFF14210A),
    primaryEdge: Color(0xFF8CC63A),
    primaryDeep: Color(0xFF5DD08A),
    panel: Color(0xFFE4EDD8),
    onPanel: Color(0xFF16200F),
    stageInk: Color(0xFFB6EE84),
    coin: Color(0xFF8FAEFF),
    onCoin: Color(0xFF10160D),
    success: Color(0xFF5DD08A),
    danger: Color(0xFFFF8A7A),
    stageSky: Color(0xFF1D2C15),
    stageGround: Color(0xFF2A3F1D),
    stageGroundLine: Color(0xFF3E5C2A),
    paceSlow: Color(0xFF4D7722),
    paceMid: Color(0xFF61AE13),
    paceFast: Color(0xFFEAF6AC),
    spriteRim: Color(0xFFEEF4E6),
    bubble: Color(0xFF44573A),
    // elevation-float 다크: 어두운 바탕에서 그림자는 거의 안 보이므로 검정 20% 한 겹만 둔다.
    // 면 구분은 연두 면 자체(바탕 13:1)와 surface 한 단계 밝기가 맡는다.
    floatShadow: [
      BoxShadow(
        color: Color(0x33000000),
        offset: Offset(0, 2),
        blurRadius: 4,
        spreadRadius: -1,
      ),
    ],
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceSoft,
    Color? line,
    Color? lineStrong,
    Color? ink,
    Color? inkMuted,
    Color? primary,
    Color? onPrimary,
    Color? primaryEdge,
    Color? primaryDeep,
    Color? panel,
    Color? onPanel,
    Color? stageInk,
    Color? coin,
    Color? onCoin,
    Color? success,
    Color? danger,
    Color? stageSky,
    Color? stageGround,
    Color? stageGroundLine,
    Color? paceSlow,
    Color? paceMid,
    Color? paceFast,
    Color? spriteRim,
    Color? bubble,
    List<BoxShadow>? floatShadow,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryEdge: primaryEdge ?? this.primaryEdge,
      primaryDeep: primaryDeep ?? this.primaryDeep,
      panel: panel ?? this.panel,
      onPanel: onPanel ?? this.onPanel,
      stageInk: stageInk ?? this.stageInk,
      coin: coin ?? this.coin,
      onCoin: onCoin ?? this.onCoin,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      stageSky: stageSky ?? this.stageSky,
      stageGround: stageGround ?? this.stageGround,
      stageGroundLine: stageGroundLine ?? this.stageGroundLine,
      paceSlow: paceSlow ?? this.paceSlow,
      paceMid: paceMid ?? this.paceMid,
      paceFast: paceFast ?? this.paceFast,
      spriteRim: spriteRim ?? this.spriteRim,
      bubble: bubble ?? this.bubble,
      floatShadow: floatShadow ?? this.floatShadow,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceSoft: l(surfaceSoft, other.surfaceSoft),
      line: l(line, other.line),
      lineStrong: l(lineStrong, other.lineStrong),
      ink: l(ink, other.ink),
      inkMuted: l(inkMuted, other.inkMuted),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      primaryEdge: l(primaryEdge, other.primaryEdge),
      primaryDeep: l(primaryDeep, other.primaryDeep),
      panel: l(panel, other.panel),
      onPanel: l(onPanel, other.onPanel),
      stageInk: l(stageInk, other.stageInk),
      coin: l(coin, other.coin),
      onCoin: l(onCoin, other.onCoin),
      success: l(success, other.success),
      danger: l(danger, other.danger),
      stageSky: l(stageSky, other.stageSky),
      stageGround: l(stageGround, other.stageGround),
      stageGroundLine: l(stageGroundLine, other.stageGroundLine),
      paceSlow: l(paceSlow, other.paceSlow),
      paceMid: l(paceMid, other.paceMid),
      paceFast: l(paceFast, other.paceFast),
      spriteRim: l(spriteRim, other.spriteRim),
      bubble: l(bubble, other.bubble),
      floatShadow:
          BoxShadow.lerpList(floatShadow, other.floatShadow, t) ?? floatShadow,
    );
  }
}

/// 앱 글꼴 가족: Pretendard 서브셋(OFL 예약 글꼴 이름 때문에 이름을 바꿨다, pubspec 참고).
const _font = 'RunmagochiSans';

/// [size]·[line](줄 높이 px)·[w] 로 앱 글꼴 스타일을 만든다.
/// [tracking] 은 em 단위 자간, [numbers] 면 고정폭 숫자(tnum).
TextStyle _s(
  double size,
  double line,
  FontWeight w,
  Color c, {
  double tracking = 0,
  bool numbers = false,
}) => TextStyle(
  fontFamily: _font,
  fontSize: size,
  height: line / size,
  fontWeight: w,
  // 가변 글꼴은 fontWeight 만으로 wght 축이 보장되지 않아 함께 지정한다.
  fontVariations: [FontVariation('wght', w.value.toDouble())],
  letterSpacing: tracking == 0 ? null : tracking * size,
  fontFeatures: numbers ? const [FontFeature.tabularFigures()] : null,
  color: c,
);

/// 글자 스타일 토큰(tokens.json 의 type). 색은 테마의 ink.
/// 화면에서는 `AppText.of(context).stat` 처럼 쓴다.
@immutable
class AppText extends ThemeExtension<AppText> {
  const AppText({
    required this.distanceXl,
    required this.numberL,
    required this.title,
    required this.titleS,
    required this.stat,
    required this.button,
    required this.heading,
    required this.body,
    required this.bodyStrong,
    required this.label,
    required this.caption,
  });

  /// [ink] 색으로 모든 스타일을 만든다.
  factory AppText.withColor(Color ink) => AppText(
    distanceXl: _s(
      128,
      128,
      FontWeight.w800,
      ink,
      tracking: -0.04,
      numbers: true,
    ),
    numberL: _s(64, 68, FontWeight.w800, ink, tracking: -0.03, numbers: true),
    title: _s(26, 32, FontWeight.w800, ink, tracking: -0.02),
    titleS: _s(22, 28, FontWeight.w700, ink),
    stat: _s(22, 28, FontWeight.w800, ink, tracking: -0.02, numbers: true),
    button: _s(22, 28, FontWeight.w700, ink),
    heading: _s(17, 24, FontWeight.w800, ink),
    body: _s(17, 24, FontWeight.w500, ink),
    bodyStrong: _s(17, 24, FontWeight.w700, ink),
    label: _s(14, 20, FontWeight.w600, ink),
    caption: _s(13, 18, FontWeight.w600, ink),
  );

  /// 러닝 중 거리 128.
  final TextStyle distanceXl;

  /// 요약 거리·카운트다운 64.
  final TextStyle numberL;

  /// 화면 제목·이름·레벨 26.
  final TextStyle title;

  /// 단위(km)·종료 안내 22.
  final TextStyle titleS;

  /// 지표 값(페이스·시간) 22.
  final TextStyle stat;

  /// 버튼 22.
  final TextStyle button;

  /// 카드 제목 17.
  final TextStyle heading;

  /// 본문 17.
  final TextStyle body;
  final TextStyle bodyStrong;

  /// 라벨 14.
  final TextStyle label;

  /// 보조 설명·탭 라벨 13. 이보다 작은 글자는 없다.
  final TextStyle caption;

  static AppText of(BuildContext context) =>
      Theme.of(context).extension<AppText>()!;

  @override
  AppText copyWith({
    TextStyle? distanceXl,
    TextStyle? numberL,
    TextStyle? title,
    TextStyle? titleS,
    TextStyle? stat,
    TextStyle? button,
    TextStyle? heading,
    TextStyle? body,
    TextStyle? bodyStrong,
    TextStyle? label,
    TextStyle? caption,
  }) {
    return AppText(
      distanceXl: distanceXl ?? this.distanceXl,
      numberL: numberL ?? this.numberL,
      title: title ?? this.title,
      titleS: titleS ?? this.titleS,
      stat: stat ?? this.stat,
      button: button ?? this.button,
      heading: heading ?? this.heading,
      body: body ?? this.body,
      bodyStrong: bodyStrong ?? this.bodyStrong,
      label: label ?? this.label,
      caption: caption ?? this.caption,
    );
  }

  @override
  AppText lerp(ThemeExtension<AppText>? other, double t) {
    if (other is! AppText) return this;
    TextStyle l(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return AppText(
      distanceXl: l(distanceXl, other.distanceXl),
      numberL: l(numberL, other.numberL),
      title: l(title, other.title),
      titleS: l(titleS, other.titleS),
      stat: l(stat, other.stat),
      button: l(button, other.button),
      heading: l(heading, other.heading),
      body: l(body, other.body),
      bodyStrong: l(bodyStrong, other.bodyStrong),
      label: l(label, other.label),
      caption: l(caption, other.caption),
    );
  }
}

ThemeData appLightTheme() => _build(AppColors.light, Brightness.light);

ThemeData appDarkTheme() => _build(AppColors.dark, Brightness.dark);

/// Material 매핑
/// - scaffold 배경 = background, 카드·다이얼로그 = surface
/// - primary/onPrimary = primary/on-primary(연두), secondary/onSecondary = panel/on-panel
/// - onSurface = ink, onSurfaceVariant = ink-muted
/// - onError = surface(라이트)·background(다크): danger 위 글자, 대비 4.5 이상(테스트)
/// - surfaceContainerHighest = surface-soft, outline = line-strong, outlineVariant = line,
///   error = danger
/// 나머지 토큰(primaryEdge, primaryDeep, coin, stage*, pace* 등)은 [AppColors] 로 읽는다.
/// 입력칸·스위치·진행 표시·스낵바·화면 전환도 여기서 정한다(작업 15). 화면은 모양을 따로
/// 주지 않는다.
ThemeData _build(AppColors c, Brightness brightness) {
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.primary,
    onPrimary: c.onPrimary,
    secondary: c.panel,
    onSecondary: c.onPanel,
    error: c.danger,
    onError: brightness == Brightness.light ? c.surface : c.background,
    surface: c.surface,
    onSurface: c.ink,
    onSurfaceVariant: c.inkMuted,
    surfaceContainerHighest: c.surfaceSoft,
    outline: c.lineStrong,
    outlineVariant: c.line,
  );
  final text = AppText.withColor(c.ink);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.background,
    fontFamily: _font,
    textTheme: TextTheme(
      displayLarge: text.distanceXl,
      displayMedium: text.numberL,
      headlineMedium: text.title,
      headlineSmall: text.stat,
      titleLarge: text.button,
      titleMedium: text.heading,
      bodyLarge: text.body,
      bodyMedium: text.body,
      bodySmall: text.caption,
      labelLarge: text.label,
      labelMedium: text.label,
      labelSmall: text.caption,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      titleTextStyle: text.title,
      contentTextStyle: text.body,
    ),
    // 글자 버튼은 초록 primary-deep (양 테마 모두 surface 위 대비 4.5 이상, 테스트로 보장).
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.primaryDeep,
        textStyle: text.label,
        minimumSize: const Size(48, 48),
      ),
    ),
    // 다이얼로그 확인 버튼: 연두 면, 경계선 없이 옅은 그림자(작업 31), 48 이상 알약.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        textStyle: text.bodyStrong,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: Gap.s5),
        shape: const StadiumBorder(),
        elevation: 1,
        shadowColor: c.floatShadow.first.color.withValues(alpha: 0.5),
      ),
    ),
    // 입력칸: 흰 판 + line-strong 2 경계(바탕·카드 모두 3:1), 포커스는 primary-deep 3
    // (키보드 포커스 윤곽과 같은 두께), 오류는 danger. 모서리는 작은 카드와 같은 radius-md.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Gap.s4,
        vertical: Gap.s4,
      ),
      border: _field(c.lineStrong, Borders.edge),
      enabledBorder: _field(c.lineStrong, Borders.edge),
      disabledBorder: _field(c.line, Borders.edge),
      focusedBorder: _field(c.primaryDeep, Borders.focus),
      errorBorder: _field(c.danger, Borders.edge),
      focusedErrorBorder: _field(c.danger, Borders.focus),
      hintStyle: text.body.copyWith(color: c.inkMuted),
      suffixStyle: text.bodyStrong.copyWith(color: c.inkMuted),
      helperStyle: text.caption.copyWith(color: c.inkMuted),
      helperMaxLines: 2,
      errorStyle: text.caption.copyWith(color: c.danger),
      errorMaxLines: 2,
      counterStyle: text.caption.copyWith(color: c.inkMuted),
    ),
    // 연두 커서는 흰 판 위 1.3:1 이라 보이지 않는다. 선택 바탕은 Material 기본(연두 40%).
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.primaryDeep,
      selectionHandleColor: c.primaryDeep,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primaryDeep),
    // 슬라이더: 연두는 눌림·채움 상태 전용(결정 0029)이라 트랙·손잡이는 ProgressBar 와
    // 같이 primaryDeep 채움 + surfaceSoft 바탕으로 한다.
    sliderTheme: SliderThemeData(
      activeTrackColor: c.primaryDeep,
      inactiveTrackColor: c.surfaceSoft,
      thumbColor: c.primaryDeep,
      activeTickMarkColor: c.surface,
      inactiveTickMarkColor: c.inkMuted,
      overlayColor: c.primaryDeep.withValues(alpha: 0.12),
    ),
    // 스위치: 켜짐은 연두 면(경계 없음, 손잡이가 오른쪽), 꺼짐은 트랙 + line-strong 경계.
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.onPrimary : c.inkMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.primary : c.surfaceSoft,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? const Color(0x00000000)
            : c.lineStrong,
      ),
      trackOutlineWidth: const WidgetStatePropertyAll(Borders.edge),
    ),
    // 알림 한 줄: 어두운 판(다크는 밝은 판) 위 on-panel 본문, 아래에 붙은 띠(위 모서리만
    // radius-md), 그림자 없음. 떠 있는 카드는 화면 아래 주요 버튼을 더 많이 가려 붙인다.
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.panel,
      contentTextStyle: text.body.copyWith(color: c.onPanel),
      actionTextColor: c.onPanel,
      behavior: SnackBarBehavior.fixed,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.md)),
      ),
    ),
    // Android 화면 전환은 움직임 토큰으로. iOS 는 뒤로 밀기 제스처가 있는 기본 전환을 둔다.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: AppPageTransitionsBuilder()},
    ),
    extensions: [c, text],
  );
}

OutlineInputBorder _field(Color color, double width) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(Radii.md),
  borderSide: BorderSide(color: color, width: width),
);
