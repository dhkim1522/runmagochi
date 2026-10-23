import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../achievement/app/providers.dart';
import '../../avatar/app/providers.dart';
import '../../profile/app/providers.dart';
import '../../run/ui/history_screen.dart';
import '../../run/ui/home_screen.dart';
import '../../shop/app/providers.dart';

/// 가져오기가 성공한 뒤 데이터에 기대는 상태를 다시 읽게 한다. 설정 화면이 부른다.
/// 화면 쪽 provider 를 건드리므로 app 층이 아니라 UI 층에 둔다.
void refreshAfterImport(WidgetRef ref) {
  ref.invalidate(growthStateProvider);
  ref.invalidate(runListProvider);
  ref.invalidate(weeklyTotalProvider);
  ref.invalidate(coinBalanceProvider);
  ref.invalidate(coinHistoryProvider);
  ref.invalidate(earnedBadgesProvider);
  ref.invalidate(achievementRunsProvider);
  ref.invalidate(equippedProvider);
  ref.invalidate(ownedItemsProvider);
  ref.invalidate(themeModeProvider);
}
