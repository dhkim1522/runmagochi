# 개발 도구

> 이 저장소에서 쓰는 Claude Code 플러그인 목록과 켜는 시점. 새 PC에서는 `/kickoff` 로 이 목록을 보고 필요한 플러그인을 켠다.

## 플러그인 목록

| 플러그인 | 역할 | 사용 시점 | 기본값 | 설치 id |
| --- | --- | --- | --- | --- |
| [superpowers](https://github.com/obra/superpowers) | 아이디어 정리, 구현 계획, 테스트 먼저 작성(TDD), 코드 리뷰 흐름 | 모든 페이즈 | 켜짐 | `superpowers@claude-plugins-official` |
| [dart-flutter](https://github.com/flutter/agent-plugins) | Flutter·Dart 공식 스킬과 Dart MCP 서버 | Flutter 프로젝트 생성부터 계속 | 켜짐 | `dart-flutter@dart-flutter` |
| [ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | 색상·글꼴·컴포넌트 규칙을 묶은 디자인 시스템 생성 | 전체 UI 디자인 적용 페이즈 | 꺼짐 | `ui-ux-pro-max@ui-ux-pro-max-skill` |
| [pixel-plugin](https://github.com/willibrandon/pixel-plugin) | Aseprite 로 도트 그림·스프라이트 시트 제작 | 캐릭터·아이템 스프라이트 제작 페이즈 | 꺼짐 | `pixel-plugin@pixel-plugin` |
| [skill-creator](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/skill-creator) | 반복 작업을 프로젝트 스킬로 만들고 검증 | 반복 작업을 스킬로 만들 때 | 꺼짐 | `skill-creator@claude-plugins-official` |

## 마켓플레이스

플러그인은 마켓플레이스(플러그인 목록 저장소)에 등록돼 있어야 설치된다.

| 마켓플레이스 | GitHub 저장소 | 등록 방식 |
| --- | --- | --- |
| `claude-plugins-official` | `anthropics/claude-plugins-official` | Claude Code 첫 실행 시 자동 등록 |
| `dart-flutter` | `flutter/agent-plugins` | `.claude/settings.json` |
| `ui-ux-pro-max-skill` | `nextlevelbuilder/ui-ux-pro-max-skill` | `.claude/settings.json` |
| `pixel-plugin` | `willibrandon/pixel-plugin` | `.claude/settings.json` |

- `.claude/settings.json` 의 마켓플레이스는 폴더 신뢰(trust) 확인 후에 등록된다.
- superpowers 는 원 저장소의 `superpowers-marketplace` 에도 있지만, 버전이 고정된 공식 마켓 판을 쓴다.
- skill-creator 는 `anthropics/skills` 의 `example-skills` 묶음에도 있지만, 스킬 12개가 함께 켜지므로 단독 플러그인을 쓴다.

## 설정 위치

- **`.claude/settings.json`**: 저장소에 커밋하는 기본값. 위 표의 기본값을 담는다.
- **`.claude/settings.local.json`**: PC별 선택. `/kickoff` 가 여기에 쓴다. git에 올리지 않는다.
- 같은 플러그인을 두 파일이 다르게 정하면 `settings.local.json` 이 이긴다.

## 사전 준비

- **dart-flutter**: Dart MCP 서버가 `dart` 명령을 쓴다. Flutter SDK를 설치하고 `dart` 가 PATH에 있어야 한다.
- **pixel-plugin**: [Aseprite](https://www.aseprite.org/) 1.3 이상이 설치돼 있어야 한다.
- **skill-creator**: claude.ai 계정에 skill-creator 스킬이 이미 동기화돼 있으면 켜지 않아도 된다.

## 플러그인 추가

1. 위 플러그인 목록 표에 한 줄을 추가한다.
2. 새 마켓플레이스면 마켓플레이스 표와 `.claude/settings.json` 의 `extraKnownMarketplaces` 에 추가한다.
3. `.claude/settings.json` 의 `enabledPlugins` 에 기본값을 넣는다.
