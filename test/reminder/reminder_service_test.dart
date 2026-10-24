import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/reminder/app/reminder_service.dart';
import 'package:runmagochi/reminder/data/reminder_scheduler.dart';
import 'package:runmagochi/reminder/domain/reminder_plan.dart';
import 'package:runmagochi/run/data/run_repository.dart';

import '../run/ui/fakes.dart';

class _Scheduler implements ReminderScheduler {
  final scheduled = <ReminderPlan>[];
  int cancels = 0;

  @override
  Future<void> schedule(ReminderPlan plan) async => scheduled.add(plan);

  @override
  Future<void> cancel() async => cancels++;
}

RunListItem _run(DateTime at) => RunListItem(
  id: 'r',
  name: '아침 러닝',
  startedAt: at,
  distanceM: 3000,
  movingTime: const Duration(minutes: 18),
  avgPaceSecPerKm: 360,
);

void main() {
  late _Scheduler scheduler;
  late FakeProfile profile;

  ReminderService service(List<RunListItem> runs) => ReminderService(
    profile: profile,
    runs: FakeRepo((0, 0), runs: runs),
    growth: FakeGrowthService(growthState(name: '말랑이')),
    scheduler: scheduler,
    clock: () => DateTime(2026, 10, 20, 9),
  );

  setUp(() {
    scheduler = _Scheduler();
    profile = FakeProfile();
  });

  test('켜져 있으면 지난 예약을 지우고 최근 러닝 기준으로 다시 예약한다', () async {
    await service([_run(DateTime(2026, 10, 20, 7))]).refresh();
    expect(scheduler.cancels, 1);
    expect(scheduler.scheduled.single.at, DateTime(2026, 10, 23, 19));
    expect(scheduler.scheduled.single.title, '말랑이 기다리는 중');
  });

  test('꺼져 있으면 지우기만 한다', () async {
    profile.reminderOn = false;
    await service([_run(DateTime(2026, 10, 20, 7))]).refresh();
    expect(scheduler.cancels, 1);
    expect(scheduler.scheduled, isEmpty);
  });

  test('러닝이 없으면 예약하지 않는다', () async {
    await service(const []).refresh();
    expect(scheduler.scheduled, isEmpty);
  });

  test('어떤 실패도 밖으로 던지지 않는다', () async {
    final s = ReminderService(
      profile: profile,
      runs: FakeRepo((0, 0), runs: [_run(DateTime(2026, 10, 20, 7))]),
      growth: FakeGrowthService(growthState())..failLoad = true,
      scheduler: scheduler,
      clock: () => DateTime(2026, 10, 20, 9),
    );
    await s.refresh();
    expect(scheduler.scheduled, isEmpty);
  });
}
