import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/app.dart';
import 'package:runmagochi/avatar/app/providers.dart';
import 'package:runmagochi/avatar/data/growth_repository.dart';
import 'package:runmagochi/avatar/domain/avatar_name.dart';
import 'package:runmagochi/avatar/ui/avatar_screen.dart';
import 'package:runmagochi/backup/app/backup_service.dart';
import 'package:runmagochi/backup/app/providers.dart';
import 'package:runmagochi/core/app_info.dart';
import 'package:runmagochi/core/korean.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/core/ui/components.dart';
import 'package:runmagochi/health/app/health_sync_service.dart';
import 'package:runmagochi/health/app/providers.dart';
import 'package:runmagochi/profile/app/providers.dart';
import 'package:runmagochi/profile/data/profile_repository.dart';
import 'package:runmagochi/reminder/app/providers.dart';
import 'package:runmagochi/reminder/app/reminder_service.dart';
import 'package:runmagochi/run/app/permission_gate.dart';
import 'package:runmagochi/run/app/providers.dart';
import 'package:runmagochi/run/ui/home_screen.dart';
import 'package:runmagochi/settings/ui/settings_screen.dart';

import '../run/ui/fakes.dart';

class _Profile implements ProfileRepository {
  double? weight;

  @override
  Future<double?> weightKg() async => weight;

  @override
  Future<void> setWeightKg(double? kg) async => weight = kg;

  bool voice = true;

  /// true 면 setVoiceGuide 가 실패한다.
  bool voiceFails = false;

  @override
  Future<bool> voiceGuide() async => voice;

  @override
  Future<void> setVoiceGuide(bool on) async {
    if (voiceFails) throw StateError('저장 실패');
    voice = on;
  }

  bool healthOn = false;

  @override
  Future<bool> health() async => healthOn;

  @override
  Future<void> setHealth(bool on) async => healthOn = on;

  bool reminderOn = true;

  @override
  Future<bool> reminder() async => reminderOn;

  @override
  Future<void> setReminder(bool on) async => reminderOn = on;

  ThemeMode theme = ThemeMode.system;

  @override
  Future<ThemeMode> themeMode() async => theme;

  @override
  Future<void> setThemeMode(ThemeMode mode) async => theme = mode;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// 이름을 바꾸면 성장 상태(가짜 서비스)의 이름도 바꾼다.
class _GrowthRepo implements GrowthRepository {
  _GrowthRepo(this.growth);
  final FakeGrowthService growth;
  final List<String> names = [];

  @override
  Future<void> setAvatarName(String name) async {
    if (validateAvatarName(name) != null) throw ArgumentError(name);
    names.add(name.trim());
    growth.state = growthState(name: name.trim());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _Backup implements BackupService {
  BackupResult exportResult = const BackupDone();
  BackupResult importResult = const BackupDone();
  BackupResult resetResult = const BackupDone();
  int exports = 0;
  int imports = 0;
  int resets = 0;

  @override
  Future<BackupResult> reset() async {
    resets++;
    return resetResult;
  }

  @override
  Future<BackupResult> export() async {
    exports++;
    return exportResult;
  }

  /// 지정하면 import 가 이 Completer 가 끝날 때까지 기다린다.
  Completer<void>? holdImport;

  @override
  Future<BackupResult> import() async {
    imports++;
    await holdImport?.future;
    return importResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// 켜기·들이기 횟수를 센다. 켜기는 실제 서비스처럼 허용되면 프로필에 켜짐을 저장한다.
class _Health implements HealthSyncService {
  _Health(this.owner);
  final _Profile owner;
  bool enableResult = true;
  int enables = 0;
  int syncs = 0;

  @override
  Future<bool> enable() async {
    enables++;
    await owner.setHealth(enableResult);
    return enableResult;
  }

  bool supported = true;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<int> sync() async {
    syncs++;
    return 0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// 다시 예약을 부른 횟수만 센다.
class _Reminders implements ReminderService {
  int refreshes = 0;

  @override
  Future<void> refresh() async => refreshes++;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class SettingsEnv {
  final growth = FakeGrowthService(growthState());
  final profile = _Profile();
  final backup = _Backup();
  final reminders = _Reminders();
  late final health = _Health(profile);
  late final repo = _GrowthRepo(growth);
}

/// [under] 위에 설정 화면을 연다. [open] 이 false 면 [under] 만 띄운다.
Future<SettingsEnv> pumpSettings(
  WidgetTester tester, {
  SettingsEnv? env,
  Widget under = const SizedBox(),
  bool open = true,
  double textScale = 1,
  ThemeData? theme,
}) async {
  final e = env ?? SettingsEnv();
  // 기본 화면(800x600)에는 설정이 다 들어가지 않으므로, 크기를 안 정한 테스트는 키 큰 화면으로 연다.
  if (tester.view.physicalSize == const Size(2400, 1800)) {
    tester.view.physicalSize = const Size(2400, 4200);
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        growthServiceProvider.overrideWithValue(e.growth),
        growthRepositoryProvider.overrideWithValue(e.repo),
        profileRepositoryProvider.overrideWithValue(e.profile),
        backupServiceProvider.overrideWithValue(e.backup),
        reminderServiceProvider.overrideWithValue(e.reminders),
        healthSyncServiceProvider.overrideWithValue(e.health),
        healthAvailableProvider.overrideWithValue(true),
        runControllerProvider.overrideWith(() => FakeController()),
        permissionGateProvider.overrideWithValue(FakeGate(GateResult.ready)),
        runRepositoryProvider.overrideWithValue(FakeRepo((0, 0))),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 17)),
      ],
      child: MaterialApp(
        theme: theme ?? appLightTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(body: under),
      ),
    ),
  );
  await settle(tester);
  if (open) await openSettings(tester);
  return e;
}

Future<void> openSettings(WidgetTester tester) async {
  final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
  nav.push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
  await settle(tester);
}

/// 아래 화면의 아바타 티커가 멈추지 않아 pumpAndSettle 대신 고정 시간만 흘린다.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

FilledButton _save(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, '저장'));

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(find.text('저장'));
  await settle(tester);
}

/// 작업 15: 새 시스템 짜임새.
void task15Tests() {
  for (final dark in [false, true]) {
    final name = dark ? '다크' : '라이트';
    final c = dark ? AppColors.dark : AppColors.light;
    ThemeData theme() => dark ? appDarkTheme() : appLightTheme();

    testWidgets('머리줄은 뒤로 흰 동그라미, 묶음 이름은 heading, 묶음 사이 28 ($name)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpSettings(tester, theme: theme());
      final back = find.byKey(const ValueKey('settings-back'));
      expect(tester.widget(back), isA<CircleIconButton>());
      for (final s in ['내 정보', '러닝 · 아바타', '백업', '정보']) {
        final style = tester.widget<Text>(find.text(s)).style!;
        expect(style.fontSize, 17, reason: s);
        expect(style.fontWeight, FontWeight.w800, reason: s);
        expect(style.color, c.ink, reason: s);
      }
      // 첫 카드 아래 → 다음 묶음 이름 위 = 섹션 사이 28.
      final firstCard = find
          .ancestor(of: find.text('체중'), matching: find.byType(AppCard))
          .first;
      expect(
        tester.getRect(find.text('러닝 · 아바타')).top -
            tester.getRect(firstCard).bottom,
        Gap.s7,
      );
      // 묶음 이름 아래 카드까지 12.
      expect(
        tester.getRect(firstCard).top -
            tester.getRect(find.text('내 정보')).bottom,
        Gap.s3,
      );
    });

    testWidgets('행 꺾쇠는 inkMuted, 값은 primaryDeep, 백업 설명은 label 14 ($name)', (
      tester,
    ) async {
      await pumpSettings(tester, theme: theme());
      for (final icon in tester.widgetList<Icon>(
        find.byIcon(Icons.chevron_right),
      )) {
        expect(icon.color, c.inkMuted);
      }
      expect(
        tester.widget<Text>(find.text('입력 안 함')).style!.color,
        c.primaryDeep,
      );
      final desc = tester
          .widget<Text>(
            find.text(
              keepAll(
                '기기를 바꿀 때 백업 파일로 기록을 옮겨요.\n가져오면 지금 데이터는 백업 내용으로 모두 바뀌어요.',
              ),
            ),
          )
          .style!;
      expect(desc.fontSize, 14);
      expect(desc.color, c.inkMuted);
    });

    testWidgets('스위치·입력칸 모양은 테마가 정한다 ($name)', (tester) async {
      await pumpSettings(tester, theme: theme());
      for (final sw in tester.widgetList<Switch>(find.byType(Switch))) {
        expect(sw.activeTrackColor, isNull);
        expect(sw.trackOutlineColor, isNull);
        expect(sw.inactiveThumbColor, isNull);
      }
      await tester.tap(find.text('체중'));
      await settle(tester);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration!.enabledBorder, isNull);
      expect(field.decoration!.fillColor, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('360×640 글자 1.3배에서 넘치지 않는다 ($name)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpSettings(tester, theme: theme(), textScale: 1.3);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('화면 모드'), 200);
      // 칩이 가장자리에 걸리지 않게 화면 안으로 가져온다.
      await tester.ensureVisible(find.text('시스템'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      for (final chip in ['시스템', '라이트', '다크']) {
        expect(find.text(chip).hitTestable(), findsOneWidget, reason: chip);
      }
      await tester.tap(find.text('다크'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('버전'), 200);
      expect(tester.takeException(), isNull);
    });
  }
}

/// 제목이 [title] 인 스위치 행의 Switch. 제목 글자와 가장 가까운 스위치를 고른다.
Switch switchOf(WidgetTester tester, String title) {
  final y = tester.getCenter(find.text(title)).dy;
  final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
  final centers = [
    for (final e in find.byType(Switch).evaluate())
      tester.getCenter(find.byElementPredicate((x) => x == e)).dy,
  ];
  var best = 0;
  for (var i = 1; i < centers.length; i++) {
    if ((centers[i] - y).abs() < (centers[best] - y).abs()) best = i;
  }
  return switches[best];
}

void main() {
  task15Tests();
  testWidgets('시안의 묶음과 행이 보인다', (tester) async {
    // 묶음 사이가 28 로 넓어져(작업 15) 한 화면에 다 보이게 키 큰 화면을 쓴다.
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpSettings(tester);
    expect(find.text('설정'), findsOneWidget);
    for (final s in ['내 정보', '러닝 · 아바타', '백업', '정보']) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
    expect(find.text('체중'), findsOneWidget);
    expect(find.text('칼로리 계산에만 써요'), findsOneWidget);
    expect(find.text('입력 안 함'), findsOneWidget);
    expect(find.textContaining('주간 목표'), findsNothing);
    expect(find.textContaining('이번 주 목표'), findsNothing);
    expect(find.text('아바타 이름'), findsOneWidget);
    expect(find.text('러니'), findsOneWidget);
    expect(
      find.text(
        keepAll('기기를 바꿀 때 백업 파일로 기록을 옮겨요.\n가져오면 지금 데이터는 백업 내용으로 모두 바뀌어요.'),
      ),
      findsOneWidget,
    );
    expect(find.text('내보내기'), findsOneWidget);
    expect(find.text('가져오기'), findsOneWidget);
    expect(find.text('오픈소스 라이선스'), findsOneWidget);
    expect(find.text('버전'), findsOneWidget);
    expect(find.text(appVersion), findsOneWidget);
  });

  testWidgets('제목은 헤더, 행은 하나의 버튼 노드, 뒤로 버튼은 이름이 있다', (tester) async {
    final env = SettingsEnv()..profile.weight = 65;
    await pumpSettings(tester, env: env);
    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.text('설정')),
      matchesSemantics(label: '설정', isHeader: true),
    );
    expect(find.bySemanticsLabel('체중, 65kg'), findsOneWidget);
    expect(find.bySemanticsLabel('아바타 이름, 러니'), findsOneWidget);
    expect(find.bySemanticsLabel('뒤로'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('settings-back'))),
      const Size(48, 48),
    );
    handle.dispose();
  });

  group('체중', () {
    Future<void> openWeight(WidgetTester tester) async {
      await tester.tap(find.text('체중'));
      await settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
    }

    testWidgets('30~200kg 만 저장되고 범위 밖이면 안내가 필드 아래에 뜬다', (tester) async {
      final env = await pumpSettings(tester);
      await openWeight(tester);
      for (final bad in ['29.9', '0', '201', '6..5']) {
        await _type(tester, bad);
        expect(_save(tester).onPressed, isNull, reason: bad);
        expect(find.text('30~200kg 사이로 입력해 주세요'), findsOneWidget);
      }
      for (final ok in ['30', '200', '65.5']) {
        await _type(tester, ok);
        expect(_save(tester).onPressed, isNotNull, reason: ok);
        expect(find.text('30~200kg 사이로 입력해 주세요'), findsNothing);
      }
      await _tapSave(tester);
      expect(env.profile.weight, 65.5);
      expect(find.text('65.5kg'), findsOneWidget);
    });

    testWidgets('저장 후 다시 열면 값이 남아 있다', (tester) async {
      final env = await pumpSettings(tester);
      await openWeight(tester);
      await _type(tester, '70');
      await _tapSave(tester);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await settle(tester);
      expect(find.byType(SettingsScreen), findsNothing);

      await openSettings(tester);
      expect(env.profile.weight, 70);
      expect(find.text('70kg'), findsOneWidget);
      await openWeight(tester);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '70',
      );
    });

    testWidgets('비우고 저장하면 체중을 지우고 입력 안 함으로 보인다', (tester) async {
      final env = SettingsEnv()..profile.weight = 72;
      await pumpSettings(tester, env: env);
      expect(find.text('72kg'), findsOneWidget);
      await openWeight(tester);
      await _type(tester, '');
      expect(_save(tester).onPressed, isNotNull);
      await _tapSave(tester);
      expect(env.profile.weight, isNull);
      expect(find.text('입력 안 함'), findsOneWidget);
    });

    testWidgets('취소하면 바뀌지 않는다', (tester) async {
      final env = SettingsEnv()..profile.weight = 72;
      await pumpSettings(tester, env: env);
      await openWeight(tester);
      await _type(tester, '80');
      await tester.tap(find.text('취소'));
      await settle(tester);
      expect(env.profile.weight, 72);
      expect(find.text('72kg'), findsOneWidget);
    });
  });

  group('아바타 이름', () {
    testWidgets('비우면 안내가 뜨고 저장할 수 없다', (tester) async {
      await pumpSettings(tester);
      await tester.tap(find.text('아바타 이름'));
      await settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      await _type(tester, '   ');
      expect(find.text('이름을 입력해 주세요'), findsOneWidget);
      expect(_save(tester).onPressed, isNull);
      await _type(tester, '삐약이');
      expect(find.text('이름을 입력해 주세요'), findsNothing);
      expect(_save(tester).onPressed, isNotNull);
    });

    testWidgets('10자를 넘겨 입력할 수 없다', (tester) async {
      await pumpSettings(tester);
      await tester.tap(find.text('아바타 이름'));
      await settle(tester);
      await _type(tester, '가나다라마바사아자차카타');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '가나다라마바사아자차',
      );
    });

    testWidgets('바꾼 이름이 아바타 탭에 반영된다', (tester) async {
      final env = await pumpSettings(tester, under: const AvatarScreen());
      await tester.tap(find.text('아바타 이름'));
      await settle(tester);
      await _type(tester, ' 삐약이 ');
      await _tapSave(tester);
      expect(env.repo.names, ['삐약이']);
      expect(find.text('삐약이'), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await settle(tester);
      expect(find.text('삐약이 Lv.3'), findsOneWidget);
    });
  });

  group('백업', () {
    testWidgets('내보내기는 서비스를 부르고 끝나면 스낵바로 알린다', (tester) async {
      final env = await pumpSettings(tester);
      await tester.tap(find.text('내보내기'));
      await settle(tester);
      expect(env.backup.exports, 1);
      expect(find.text('백업 파일을 저장했어요'), findsOneWidget);
    });

    testWidgets('내보내기를 취소하면 아무것도 띄우지 않는다', (tester) async {
      final env = SettingsEnv()..backup.exportResult = const BackupCancelled();
      await pumpSettings(tester, env: env);
      await tester.tap(find.text('내보내기'));
      await settle(tester);
      expect(env.backup.exports, 1);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('러닝 중이면 할 수 없다고 알린다', (tester) async {
      final env = SettingsEnv()
        ..backup.exportResult = const BackupBlockedByRun();
      await pumpSettings(tester, env: env);
      await tester.tap(find.text('내보내기'));
      await settle(tester);
      expect(find.text('러닝 중에는 할 수 없어요'), findsOneWidget);
    });

    testWidgets('실패하면 서비스의 문장을 그대로 보여 준다', (tester) async {
      final env = SettingsEnv()
        ..backup.exportResult = const BackupFailed('백업 파일을 저장하지 못했어요');
      await pumpSettings(tester, env: env);
      await tester.tap(find.text('내보내기'));
      await settle(tester);
      expect(find.text('백업 파일을 저장하지 못했어요'), findsOneWidget);
    });

    Future<void> openImport(WidgetTester tester) async {
      await tester.tap(find.text('가져오기'));
      await settle(tester);
      expect(find.text('백업 파일을 가져올까요?'), findsOneWidget);
      expect(
        find.text(keepAll('지금 데이터가 모두 백업 내용으로 바뀌어요.\n되돌릴 수 없어요.')),
        findsOneWidget,
      );
    }

    testWidgets('가져오기 확인 창에서 취소하면 서비스를 부르지 않는다', (tester) async {
      final env = await pumpSettings(tester);
      await openImport(tester);
      await tester.tap(find.text('취소'));
      await settle(tester);
      expect(env.backup.imports, 0);
      expect(find.text('백업 파일을 가져올까요?'), findsNothing);
    });

    testWidgets('가져오기 버튼은 danger 색이다', (tester) async {
      await pumpSettings(tester);
      await openImport(tester);
      final button = tester.widget<TextButton>(
        find.ancestor(
          of: find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('가져오기'),
          ),
          matching: find.byType(TextButton),
        ),
      );
      expect(
        button.style!.foregroundColor!.resolve({}),
        AppColors.light.danger,
      );
    });

    testWidgets('확인하면 가져오고 화면 상태를 다시 읽는다', (tester) async {
      final env = await pumpSettings(tester);
      final loads = env.growth.loads;
      env.growth.state = growthState(name: '말랑이');
      env.profile.weight = 58;
      await openImport(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('가져오기'),
        ),
      );
      await settle(tester);
      expect(env.backup.imports, 1);
      expect(env.growth.loads, greaterThan(loads));
      expect(find.text('백업을 가져왔어요'), findsOneWidget);
      expect(find.text('말랑이'), findsOneWidget);
      expect(find.text('58kg'), findsOneWidget);
    });

    testWidgets('가져오는 동안 뒤로 갈 수 없고, 끝나면 화면 상태를 다시 읽는다', (tester) async {
      final env = SettingsEnv();
      final hold = env.backup.holdImport = Completer<void>();
      await pumpSettings(tester, env: env);
      final loads = env.growth.loads;
      env.growth.state = growthState(name: '말랑이');
      await openImport(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('가져오기'),
        ),
      );
      await settle(tester);
      expect(env.backup.imports, 1);

      // 시스템 뒤로 가기도, 화면의 뒤로 버튼도 막힌다.
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(
        tester
            .widget<CircleIconButton>(
              find.byKey(const ValueKey('settings-back')),
            )
            .onPressed,
        isNull,
      );

      hold.complete();
      await settle(tester);
      expect(env.growth.loads, greaterThan(loads));
      expect(find.text('백업을 가져왔어요'), findsOneWidget);
      expect(find.text('말랑이'), findsOneWidget);

      // 끝나면 다시 뒤로 갈 수 있다.
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byType(SettingsScreen), findsNothing);
    });

    testWidgets('가져오기가 러닝 중이라 막히면 알린다', (tester) async {
      final env = SettingsEnv()
        ..backup.importResult = const BackupBlockedByRun();
      await pumpSettings(tester, env: env);
      await openImport(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('가져오기'),
        ),
      );
      await settle(tester);
      expect(find.text('러닝 중에는 할 수 없어요'), findsOneWidget);
    });
  });

  group('초기화', () {
    Future<void> openReset(WidgetTester tester) async {
      await tester.scrollUntilVisible(find.text('모든 기록 지우고 처음부터'), 200);
      await tester.pump();
      await tester.tap(find.text('모든 기록 지우고 처음부터'));
      await settle(tester);
      expect(find.text('모든 기록을 지울까요?'), findsOneWidget);
    }

    Future<void> confirmReset(WidgetTester tester) async {
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('지우기'),
        ),
      );
      await settle(tester);
    }

    testWidgets('설명은 지우는 것과 남는 것을 말한다', (tester) async {
      await pumpSettings(tester);
      await tester.scrollUntilVisible(find.text('모든 기록 지우고 처음부터'), 200);
      expect(find.text('초기화'), findsOneWidget);
      expect(
        find.text(
          keepAll('기록과 캐릭터를 모두 지우고 캐릭터를 새로 만들어요.\n체중·음성 안내·화면 모드는 남아요.'),
        ),
        findsOneWidget,
      );
      // 되돌릴 수 없는 동작이라 빨간 테두리·글자의 위험 버튼이다.
      expect(find.widgetWithText(AppButton, '모든 기록 지우고 처음부터'), findsOneWidget);
      final button = tester.widget<AppButton>(
        find.widgetWithText(AppButton, '모든 기록 지우고 처음부터'),
      );
      expect(button, isA<AppButton>());
      expect(
        tester.widget<Text>(find.text('모든 기록 지우고 처음부터')).style!.color,
        AppColors.light.danger,
      );
    });

    testWidgets('확인 창은 지우는 것과 되돌릴 수 없음을 줄을 나눠 말한다', (tester) async {
      await pumpSettings(tester);
      await openReset(tester);
      expect(
        find.text(
          keepAll(
            '러닝 기록, 캐릭터, 경험치, 코인, 아이템, 배지가 모두 지워져요.\n'
            '되돌릴 수 없으니 필요하면 먼저 백업을 내보내 주세요.',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('확인 창에서 취소하면 서비스를 부르지 않는다', (tester) async {
      final env = await pumpSettings(tester);
      await openReset(tester);
      await tester.tap(find.text('취소'));
      await settle(tester);
      expect(env.backup.resets, 0);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('지우기 버튼은 danger 색이다', (tester) async {
      await pumpSettings(tester);
      await openReset(tester);
      final button = tester.widget<TextButton>(
        find.ancestor(of: find.text('지우기'), matching: find.byType(TextButton)),
      );
      expect(
        button.style!.foregroundColor!.resolve({}),
        AppColors.light.danger,
      );
    });

    testWidgets('확인하면 초기화하고 설정을 닫는다', (tester) async {
      final env = await pumpSettings(tester);
      await openReset(tester);
      await confirmReset(tester);
      expect(env.backup.resets, 1);
      expect(find.byType(SettingsScreen), findsNothing);
    });

    testWidgets('러닝 중이라 막히면 알리고 설정에 남는다', (tester) async {
      final env = SettingsEnv()
        ..backup.resetResult = const BackupBlockedByRun();
      await pumpSettings(tester, env: env);
      await openReset(tester);
      await confirmReset(tester);
      expect(find.text('러닝 중에는 할 수 없어요'), findsOneWidget);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('실패하면 서비스의 문장을 보여 주고 설정에 남는다', (tester) async {
      final env = SettingsEnv()
        ..backup.resetResult = const BackupFailed('데이터를 지우지 못했어요');
      await pumpSettings(tester, env: env);
      await openReset(tester);
      await confirmReset(tester);
      expect(find.text('데이터를 지우지 못했어요'), findsOneWidget);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });

  testWidgets('오픈소스 라이선스를 누르면 라이선스 화면이 열린다', (tester) async {
    await pumpSettings(tester);
    // 묶음 사이가 28 로 넓어져(작업 15) 기본 800×600 에서는 아래 행이 아직 만들어지지 않는다.
    await tester.scrollUntilVisible(find.text('오픈소스 라이선스'), 200);
    await tester.pump();
    await tester.tap(find.text('오픈소스 라이선스'));
    await settle(tester);
    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('홈 오른쪽 위 톱니(설정 버튼)로 설정이 열린다', (tester) async {
    await pumpSettings(tester, under: const HomeScreen(), open: false);
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('설정'), findsOneWidget);
    handle.dispose();
    final gear = find.byKey(const ValueKey('home-settings'));
    expect(tester.getSize(gear), const Size(48, 48));
    await tester.tap(gear);
    await settle(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  group('화면 모드', () {
    testWidgets('기본은 시스템이고 다크를 고르면 저장된다', (tester) async {
      final env = await pumpSettings(tester);
      expect(find.text('화면 모드'), findsOneWidget);
      expect(find.text('시스템'), findsOneWidget);
      expect(find.text('라이트'), findsOneWidget);
      await tester.tap(find.text('다크'));
      await settle(tester);
      expect(env.profile.theme, ThemeMode.dark);
    });

    testWidgets('고르면 앱 테마가 바뀐다', (tester) async {
      final profile = FakeProfile();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            runControllerProvider.overrideWith(FakeController.new),
            runRepositoryProvider.overrideWithValue(FakeRepo((0, 0))),
            profileRepositoryProvider.overrideWithValue(profile),
            notificationSchedulerProvider.overrideWithValue(
              FakeNotificationScheduler(),
            ),
            growthServiceProvider.overrideWithValue(
              FakeGrowthService(growthState()),
            ),
            growthRepositoryProvider.overrideWithValue(
              _GrowthRepo(FakeGrowthService(growthState())),
            ),
          ],
          child: const RunmagochiApp(),
        ),
      );
      await tester.pump();
      await tester.pump();
      MaterialApp app() => tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app().themeMode, ThemeMode.system);
      await tester.tap(find.byKey(const ValueKey('home-settings')));
      await settle(tester);
      await tester.tap(find.text('다크'));
      await settle(tester);
      expect(app().themeMode, ThemeMode.dark);
    });
  });

  group('건강 앱 연동 (F15)', () {
    Switch healthSwitch(WidgetTester tester) =>
        switchOf(tester, '건강 앱에서 러닝 가져오기');

    testWidgets('기본은 꺼져 있고, 켜면 권한을 요청한 뒤 바로 들인다', (tester) async {
      final env = await pumpSettings(tester);
      expect(find.text('건강 앱에서 러닝 가져오기'), findsOneWidget);
      expect(find.text('워치로 달린 러닝도 캐릭터가 자라요'), findsOneWidget);
      expect(healthSwitch(tester).value, isFalse);
      await tester.tap(find.text('건강 앱에서 러닝 가져오기'));
      await settle(tester);
      expect(env.health.enables, 1);
      expect(env.health.syncs, 1);
      expect(env.profile.healthOn, isTrue);
    });

    testWidgets('권한을 거절하면 켜지 않고 알린다', (tester) async {
      final env = SettingsEnv()..health.enableResult = false;
      await pumpSettings(tester, env: env);
      await tester.tap(find.text('건강 앱에서 러닝 가져오기'));
      await settle(tester);
      expect(env.profile.healthOn, isFalse);
      expect(find.text('건강 앱 권한을 허용해야 가져올 수 있어요'), findsOneWidget);
      expect(env.health.syncs, 0);
    });

    testWidgets('건강 앱을 쓸 수 없는 기기면 설치를 안내한다', (tester) async {
      final env = SettingsEnv()
        ..health.enableResult = false
        ..health.supported = false;
      await pumpSettings(tester, env: env);
      await tester.tap(find.text('건강 앱에서 러닝 가져오기'));
      await settle(tester);
      expect(find.textContaining('Health Connect'), findsOneWidget);
    });

    testWidgets('끄면 저장하고 가져오지 않는다', (tester) async {
      final env = SettingsEnv()..profile.healthOn = true;
      await pumpSettings(tester, env: env);
      await tester.tap(find.text('건강 앱에서 러닝 가져오기'));
      await settle(tester);
      expect(env.profile.healthOn, isFalse);
      expect(env.health.enables, 0);
    });
  });

  group('쉬는 날 알림 (F27)', () {
    Switch reminderSwitch(WidgetTester tester) => switchOf(tester, '쉬는 날 알림');

    testWidgets('기본으로 켜져 있고, 바꾸면 저장하고 알림을 다시 예약한다', (tester) async {
      final env = await pumpSettings(tester);
      expect(find.text('쉬는 날 알림'), findsOneWidget);
      expect(find.text('며칠 쉬면 캐릭터가 한 번 불러요'), findsOneWidget);
      expect(reminderSwitch(tester).value, isTrue);
      await tester.tap(find.text('쉬는 날 알림'));
      await settle(tester);
      expect(env.profile.reminderOn, isFalse);
      expect(reminderSwitch(tester).value, isFalse);
      expect(env.reminders.refreshes, 1);
    });

    testWidgets('가져오기·초기화 뒤에도 다시 예약한다', (tester) async {
      final env = await pumpSettings(tester);
      await tester.tap(find.text('가져오기'));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('가져오기'),
        ),
      );
      await settle(tester);
      expect(env.reminders.refreshes, 1);
    });
  });

  group('음성 안내', () {
    // 음성 안내가 첫 스위치, 쉬는 날 알림이 둘째다.
    Switch voiceSwitch(WidgetTester tester) =>
        tester.widgetList<Switch>(find.byType(Switch)).first;

    testWidgets('기본으로 켜져 있고 끄면 저장된다', (tester) async {
      final env = await pumpSettings(tester);
      expect(find.text('음성 안내'), findsOneWidget);
      expect(voiceSwitch(tester).value, isTrue);
      await tester.tap(find.text('음성 안내'));
      await settle(tester);
      expect(env.profile.voice, isFalse);
      expect(voiceSwitch(tester).value, isFalse);
      await tester.tap(find.text('음성 안내'));
      await settle(tester);
      expect(env.profile.voice, isTrue);
      expect(voiceSwitch(tester).value, isTrue);
    });

    testWidgets('꺼진 저장값을 보여 준다', (tester) async {
      final env = SettingsEnv()..profile.voice = false;
      await pumpSettings(tester, env: env);
      expect(voiceSwitch(tester).value, isFalse);
    });

    testWidgets('저장에 실패하면 되돌리고 알린다', (tester) async {
      final env = SettingsEnv()..profile.voiceFails = true;
      await pumpSettings(tester, env: env);
      await tester.tap(find.text('음성 안내'));
      await settle(tester);
      expect(voiceSwitch(tester).value, isTrue);
      expect(find.text('음성 안내를 바꾸지 못했어요'), findsOneWidget);
    });

    testWidgets('하나의 스위치 노드로 읽힌다', (tester) async {
      await pumpSettings(tester);
      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.text('음성 안내')),
        matchesSemantics(
          label: '음성 안내\n러닝 중 거리와 시간을 말로 알려줘요',
          hasToggledState: true,
          isToggled: true,
          hasTapAction: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      handle.dispose();
    });
  });

  testWidgets('글자 크기 1.3배에서 overflow 없이 그려진다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final env = SettingsEnv()..profile.weight = 65;
    env.growth.state = growthState(name: '가나다라마바사아자차');
    await pumpSettings(tester, env: env, textScale: 1.3);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('버전'), 200);
    expect(tester.takeException(), isNull);
  });

  testWidgets('다크 테마에서도 그려진다', (tester) async {
    await pumpSettings(tester, theme: appDarkTheme());
    expect(tester.takeException(), isNull);
    expect(find.text('설정'), findsOneWidget);
    final title = tester.widget<Text>(find.text('설정'));
    expect(title.style!.color, AppColors.dark.ink);
  });
}
