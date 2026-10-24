import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../avatar/ui/sprite_sheet.dart';
import '../../core/theme.dart';

/// 부화 시트(32칸 × 6프레임): 0 가만히, 1 왼쪽, 2 오른쪽, 3 금 1, 4 금 2, 5 깨짐.
const String hatchSheet = 'assets/sprites/egg/hatch.png';
const int _hatchFrameCount = 6;

/// (프레임, 보여 주는 시간 ms). 가만히 → 흔들림 → 금 → 더 흔들림 → 큰 금 → 깨짐.
const List<(int, int)> _timeline = [
  (0, 400),
  (1, 150),
  (2, 150),
  (1, 150),
  (2, 150),
  (3, 500),
  (1, 120),
  (2, 120),
  (1, 120),
  (2, 120),
  (4, 500),
  (5, 350),
];

/// 첫 만남 부화 연출 (F33, 결정 0037). 알이 흔들리다 금이 가고 깨지면 [pet] 이 튀어나온다.
///
/// 약 3초. 누르면 바로 태어나고, 움직임 줄이기 설정이면 처음부터 [pet] 을 보인다.
/// 금이 갈 때 약한 진동, 깨질 때 중간 진동(무음이어도 느낄 수 있다). [pet] 은 처음부터
/// 같은 자리에 투명하게 두어 무대 크기가 바뀌지 않는다.
class HatchView extends StatefulWidget {
  const HatchView({super.key, required this.scale, required this.pet});

  /// 도트 배율. [pet] 과 같은 값을 쓴다.
  final int scale;
  final Widget pet;

  @override
  State<HatchView> createState() => _HatchViewState();
}

class _HatchViewState extends State<HatchView>
    with SingleTickerProviderStateMixin {
  static final int _totalMs = _timeline.fold(0, (s, e) => s + e.$2);

  late final AnimationController _clock =
      AnimationController(
          vsync: this,
          duration: Duration(milliseconds: _totalMs),
        )
        ..addListener(_tick)
        ..addStatusListener(_status);

  bool _hatched = false;
  int _frame = 0;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _hatched = true;
    } else {
      _clock.forward();
    }
  }

  void _tick() {
    var at = (_clock.value * _totalMs).round();
    var frame = _timeline.last.$1;
    for (final (f, ms) in _timeline) {
      if (at < ms) {
        frame = f;
        break;
      }
      at -= ms;
    }
    if (frame == _frame) return;
    if (frame == 3 || frame == 4) HapticFeedback.lightImpact();
    if (frame == 5) HapticFeedback.mediumImpact();
    setState(() => _frame = frame);
  }

  void _status(AnimationStatus s) {
    if (s == AnimationStatus.completed) _hatch();
  }

  void _hatch() {
    if (_hatched || !mounted) return;
    _clock.stop();
    setState(() => _hatched = true);
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final side = (spriteFramePx * widget.scale).toDouble();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _hatch,
      child: SizedBox.square(
        dimension: side,
        child: Stack(
          children: [
            AnimatedScale(
              scale: _hatched ? 1 : 0.6,
              duration: Motion.of(context, Motion.enter),
              curve: Motion.pop,
              alignment: Alignment.bottomCenter,
              child: AnimatedOpacity(
                opacity: _hatched ? 1 : 0,
                duration: Motion.of(context, Motion.quick),
                child: widget.pet,
              ),
            ),
            if (!_hatched)
              ClipRect(
                key: const ValueKey('hatch-egg'),
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: side * _hatchFrameCount,
                  maxWidth: side * _hatchFrameCount,
                  minHeight: side,
                  maxHeight: side,
                  child: Transform.translate(
                    offset: Offset(-side * _frame, 0),
                    child: Image.asset(
                      hatchSheet,
                      width: side * _hatchFrameCount,
                      height: side,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
