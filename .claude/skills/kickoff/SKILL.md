---
name: kickoff
description: runmagochi 저장소를 처음 열거나 새 PC에서 작업을 시작할 때 실행한다. 프로젝트 현황과 다음 할 일을 브리핑하고, docs/tooling.md 의 추천 플러그인을 현재 페이즈에 맞춰 골라 이 PC에만 켠다.
disable-model-invocation: true
allowed-tools: Read Bash(claude plugin list *) Bash(claude plugin details *) Bash(claude plugin marketplace list *)
---

# kickoff

> 프로젝트 현황 브리핑과 이 PC의 플러그인 설정을 한 번에 끝낸다. 모든 출력은 한국어로 짧게 쓴다.

## 규칙

- 현황·페이즈·다음 할 일은 실행할 때 파일에서 읽는다. 이 문서에 적힌 예시를 출력하지 않는다.
- 플러그인 변경은 이 PC에만 적용한다. 모든 `claude plugin` 명령에 `--scope local` 을 붙인다.
- `.claude/settings.json` 은 수정하지 않는다. 저장소 기본값은 `docs/tooling.md` 를 고치는 별도 작업으로 바꾼다.
- 명령은 macOS·Windows 공통으로 쓴다. `claude plugin ...` 만 실행하고 `grep`·`jq` 같은 셸 도구로 가공하지 않는다. 결과는 `--json` 출력을 직접 읽는다.
- `CLAUDE_CONFIG_DIR` 를 바꾸지 않는다. 현재 세션의 계정 설정을 그대로 쓴다.

## 1. 브리핑

`README.md`, `HANDOFF.md`, `docs/roadmap.md` 를 읽고 아래 형식으로 출력한다.

```
## runmagochi
<프로젝트 소개 2줄: README.md 첫 문단 요약>

**현재 페이즈**: <roadmap.md "현재 위치">
**상태**: <HANDOFF.md "현재 상태" 핵심 3줄 이내>
**다음 할 일**: <HANDOFF.md "다음 할 일" 번호 목록 제목만>
```

## 2. 플러그인 현황

1. `docs/tooling.md` 의 플러그인 목록 표와 마켓플레이스 표를 읽는다.
2. `claude plugin list --json` 으로 설치·활성 상태를 확인한다.
3. 플러그인마다 `claude plugin details <설치 id>` 를 실행해 "Always-on" 토큰 수를 읽는다.
   - 실패하면(마켓플레이스 미등록 등) 비용은 "모름" 으로 표시한다.
4. 추천 여부를 정한다.
   - `docs/roadmap.md` 의 현재 페이즈·범위·확정된 제약과 표의 "사용 시점" 을 대조한다.
   - 현재 페이즈에 해당하거나 다음 할 일에 바로 필요하면 추천한다.
5. 표 하나로 출력한다.

```
| 플러그인 | 상태 | 상시 비용 | 추천 | 근거 |
| --- | --- | --- | --- | --- |
| <이름> | 켜짐 / 꺼짐 / 미설치 | ~<n> 토큰 | 추천 / - | <사용 시점 대비 한 줄> |
```

## 3. 선택

`AskUserQuestion` 으로 켤 플러그인을 묻는다.

- `multiSelect: true` 로 묻는다.
- 추천 플러그인을 앞에 두고 라벨 끝에 "(추천)" 을 붙인다.
- 질문 하나에 선택지가 4개를 넘으면 질문을 나눈다. 예: 상시 사용 / 특정 단계 사용.
- 선택하지 않은 플러그인은 끈다는 뜻임을 질문에 적는다.

## 4. 적용

플러그인마다 아래 순서로 처리한다. 선택 결과와 현재 상태가 같으면 건너뛴다.

- **켜기, 미설치**
  1. `claude plugin marketplace list --json` 에 마켓플레이스가 없으면 `claude plugin marketplace add <GitHub 저장소> --scope local`
  2. `claude plugin install <설치 id> --scope local`
- **켜기, 설치됨·꺼짐**: `claude plugin enable <설치 id> --scope local`
- **끄기, 켜짐**: `claude plugin disable <설치 id> --scope local`
- **끄기, 미설치**: 아무것도 하지 않는다.

`already disabled`·`already installed` 메시지는 성공으로 본다. 그 외 실패는 명령과 오류 문구를 그대로 보여 준다.

## 5. 마무리

1. 변경한 플러그인과 결과를 목록으로 보여 준다.
2. 변경이 있으면 `/reload-plugins` 를 실행하거나 Claude Code를 다시 시작해야 적용된다고 알린다.
3. 사전 준비가 필요한 플러그인을 켰으면 `docs/tooling.md` "사전 준비" 의 해당 항목을 알린다.
4. `HANDOFF.md` 의 "다음 할 일" 을 그대로 보여 주고 끝낸다.
