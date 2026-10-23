import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 하단 탭 순서. 홈의 코인 칩처럼 다른 화면이 탭을 바꿀 때 쓴다.
const int shopTabIndex = 3;

/// 하단 탭에서 선택된 탭 번호.
final homeTabProvider = NotifierProvider<HomeTab, int>(HomeTab.new);

class HomeTab extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

/// 러닝 시작 카운트다운이 도는 중인지. 켜져 있으면 하단 탭을 숨긴다(러닝 중 화면과 같게).
final runCountdownProvider = NotifierProvider<RunCountdown, bool>(
  RunCountdown.new,
);

class RunCountdown extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool active) => state = active;
}
