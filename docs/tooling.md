# 개발 도구

> 이 저장소에서 쓰는 Claude Code 플러그인 목록과 켜는 시점. 새 PC에서는 `/kickoff` 로 이 목록을 보고 필요한 플러그인을 켠다. `/phase` 는 시작할 때 "사용 시점" 을 보고 이번 페이즈에 필요한 플러그인과 사전 준비를 확인한다.

## 플러그인 목록

| 플러그인 | 역할 | 사용 시점 | 기본값 | 설치 id |
| --- | --- | --- | --- | --- |
| [superpowers](https://github.com/obra/superpowers) | 아이디어 정리, 구현 계획, 테스트 먼저 작성(TDD), 코드 리뷰 흐름 | 모든 페이즈 | 켜짐 | `superpowers@claude-plugins-official` |
| [dart-flutter](https://github.com/flutter/agent-plugins) | Flutter·Dart 공식 스킬과 Dart MCP 서버 | Flutter 프로젝트 생성부터 계속 | 켜짐 | `dart-flutter@dart-flutter` |
| [ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | 색상·글꼴·컴포넌트 규칙을 묶은 디자인 시스템 생성 | 페이즈 2.5 (기본 디자인), 페이즈 3 (나머지 화면), 페이즈 6-2 (UI/UX 개편) | 꺼짐 | `ui-ux-pro-max@ui-ux-pro-max-skill` |
| [Impeccable](https://github.com/pbakaus/impeccable) | AI 티가 나는 디자인 패턴 점검, UX 리뷰(`critique`)·출시 전 마무리(`polish`) | 페이즈 6-2 (후보 시안 비교·전면 점검). 웹 대상이라 HTML 시안에 쓴다 | 꺼짐 | `impeccable@impeccable` |
| [Taste Skill](https://github.com/Leonxlnx/taste-skill) | 아트 디렉션 20개 중 3개를 뽑아 디자인 방향 후보 제시 | 페이즈 6-2 (방향 후보 만들기). 웹 대상이라 HTML 시안에 쓴다 | 꺼짐 | `taste-skill@taste-skill` |
| [pixel-plugin](https://github.com/willibrandon/pixel-plugin) | Aseprite 로 도트 그림·스프라이트 시트 제작 | 페이즈 6-1 (캐릭터 에셋). 페이즈 2.5 캐릭터는 코드로 그린다 | 꺼짐 | `pixel-plugin@pixel-plugin` |
| [skill-creator](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/skill-creator) | 반복 작업을 프로젝트 스킬로 만들고 검증 | 반복 작업을 스킬로 만들 때 | 꺼짐 | `skill-creator@claude-plugins-official` |

## 마켓플레이스

플러그인은 마켓플레이스(플러그인 목록 저장소)에 등록돼 있어야 설치된다.

| 마켓플레이스 | GitHub 저장소 | 등록 방식 |
| --- | --- | --- |
| `claude-plugins-official` | `anthropics/claude-plugins-official` | Claude Code 첫 실행 시 자동 등록 |
| `dart-flutter` | `flutter/agent-plugins` | `.claude/settings.json` |
| `ui-ux-pro-max-skill` | `nextlevelbuilder/ui-ux-pro-max-skill` | `.claude/settings.json` |
| `pixel-plugin` | `willibrandon/pixel-plugin` | `.claude/settings.json` |
| `impeccable` | `pbakaus/impeccable` | `.claude/settings.json` |
| `taste-skill` | `Leonxlnx/taste-skill` | `.claude/settings.json` |

- `.claude/settings.json` 의 마켓플레이스는 폴더 신뢰(trust) 확인 후에 등록된다.
- superpowers 는 원 저장소의 `superpowers-marketplace` 에도 있지만, 버전이 고정된 공식 마켓 판을 쓴다.
- skill-creator 는 `anthropics/skills` 의 `example-skills` 묶음에도 있지만, 스킬 12개가 함께 켜지므로 단독 플러그인을 쓴다.

## 설정 위치

- **`.claude/settings.json`**: 저장소에 커밋하는 기본값. 위 표의 기본값을 담는다.
- **`.claude/settings.local.json`**: PC별 선택. `/kickoff` 가 여기에 쓴다. git에 올리지 않는다.
- 같은 플러그인을 두 파일이 다르게 정하면 `settings.local.json` 이 이긴다.

## 사전 준비

- **Flutter 버전**: 프로젝트 Flutter 는 `.fvmrc` 로 고정한다(결정 0008). [FVM](https://fvm.app) 을 설치하고(`dart pub global activate fvm` 또는 macOS `brew install fvm`) 저장소에서 `fvm install` 을 실행한다. Windows 는 개발자 모드를 켜야 한다.
- **dart-flutter**: Dart MCP 서버가 전역 `dart` 명령을 쓴다. Flutter SDK를 설치하고 `dart` 가 PATH에 있어야 한다. 전역 버전도 `.fvmrc` 와 맞춰 두면 분석 결과가 같다.
- **글꼴 서브셋**(`tool/subset_fonts.py`): Python 3 와 fonttools. 저장소 루트에서 `python3 -m venv .venv` 후 `.venv/bin/pip install fonttools==4.67.0`(Windows `py -m venv .venv`, `.venv\Scripts\pip ...`). `.venv/` 는 git 에 올리지 않는다. 앱 문구에 새 글자를 쓸 때만 필요하다.
- **pixel-plugin**: [Aseprite](https://www.aseprite.org/) 1.3 이상이 설치돼 있어야 한다.
- **Taste Skill**: Node 22 이상과 Chrome·Edge·Chromium 중 하나가 필요하다.
- **디자인 스킬**: ui-ux-pro-max·Impeccable·Taste Skill 은 지침이 겹친다. 단계마다 필요한 것만 켠다.
- **skill-creator**: claude.ai 계정에 skill-creator 스킬이 이미 동기화돼 있으면 켜지 않아도 된다.
- **에뮬레이터(E2E)**: `/e2e` 가 처음 실행될 때 Android Emulator, 시스템 이미지(Android 37 Google APIs), AVD `runmagochi` 가 있는지 보고 없으면 설치를 묻는다. 약 2GB 다운로드. Windows 는 하드웨어 가속(Windows 하이퍼바이저 플랫폼)이 필요하다.
- **상태 표시줄**: `.claude/statusline.sh` 가 모델, 5시간·주간 사용량, 세션 시간, 컨텍스트, effort 를 하단에 표시한다. macOS 는 기본 bash, Windows 는 Git Bash 로 같은 설정이 그대로 동작한다(Claude Code 가 Windows 에서 Git Bash 로 실행). `jq` 같은 추가 설치는 필요 없다.

## 플러그인 추가

1. 위 플러그인 목록 표에 한 줄을 추가한다.
2. 새 마켓플레이스면 마켓플레이스 표와 `.claude/settings.json` 의 `extraKnownMarketplaces` 에 추가한다.
3. `.claude/settings.json` 의 `enabledPlugins` 에 기본값을 넣는다.
