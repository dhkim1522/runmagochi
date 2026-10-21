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
