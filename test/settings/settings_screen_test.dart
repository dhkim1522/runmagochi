import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/app/providers.dart';
import 'package:runmagochi/avatar/data/growth_repository.dart';
import 'package:runmagochi/avatar/domain/avatar_name.dart';
import 'package:runmagochi/avatar/ui/avatar_screen.dart';
import 'package:runmagochi/backup/app/backup_service.dart';
import 'package:runmagochi/backup/app/providers.dart';
import 'package:runmagochi/core/app_info.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/profile/app/providers.dart';
import 'package:runmagochi/profile/data/profile_repository.dart';
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
  int exports = 0;
  int imports = 0;

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

class SettingsEnv {
  final growth = FakeGrowthService(growthState());
  final profile = _Profile();
  final backup = _Backup();
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
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        growthServiceProvider.overrideWithValue(e.growth),
        growthRepositoryProvider.overrideWithValue(e.repo),
        profileRepositoryProvider.overrideWithValue(e.profile),
        backupServiceProvider.overrideWithValue(e.backup),
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

void main() {
  testWidgets('시안의 묶음과 행이 보인다', (tester) async {
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
      find.text('기기를 바꿀 때 백업 파일로 기록을 옮겨요. 가져오면 지금 데이터는 백업 내용으로 모두 바뀌어요.'),
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
      expect(find.text('지금 데이터가 모두 백업 내용으로 바뀌어요. 되돌릴 수 없어요.'), findsOneWidget);
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
            .widget<IconButton>(find.byKey(const ValueKey('settings-back')))
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

  testWidgets('오픈소스 라이선스를 누르면 라이선스 화면이 열린다', (tester) async {
    await pumpSettings(tester);
    await tester.ensureVisible(find.text('오픈소스 라이선스'));
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

  group('음성 안내', () {
    Switch voiceSwitch(WidgetTester tester) =>
        tester.widget<Switch>(find.byType(Switch));

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
