# Installation Guide

> **AI Agent**: 사용자가 이 프로젝트의 세팅이나 설치를 요청하면 아래 단계를 순서대로 실행하세요.

## Prerequisites

- macOS
- Claude Code CLI 또는 OpenAI Codex CLI (둘 다 있으면 양쪽에 설치됩니다)
- `jq` (`brew install jq`)

## 가장 빠른 방법

```bash
bash install.sh
```

아래 2~4단계를 전부 수행합니다. 재실행해도 안전합니다. 개별 단계를 직접 확인하고
싶을 때만 아래 절차를 따르세요.

```bash
bash install.sh --target codex   # 한쪽만
bash install.sh --prune          # 저장소에서 사라진 고아 심링크까지 정리
bash install.sh --help
```

## 타깃별 설치 범위

| 항목 | Claude Code | OpenAI Codex |
|------|-------------|--------------|
| 스킬 | `~/.claude/skills` | `~/.codex/skills` |
| 서브에이전트 | `~/.claude/agents` | **미지원** |
| MCP 서버 | 4종 (`claude mcp add -s user`) | 4종 (`codex mcp add`) |
| 알림음 훅 | `~/.claude/settings.json` — 3종 | `~/.codex/hooks.json` — **1종(Stop)** |
| 세션 대화 로그 | `~/.claude/projects/<mangled>/*.jsonl` | `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` |

서브에이전트는 Claude Code 전용 기능이라 Codex에는 설치되지 않습니다. Codex에는 대응
개념이 없으며, `install.sh`가 이를 감지해 해당 단계를 건너뛰고 그 사실을 출력합니다.

스킬 포맷과 MCP 핀 버전은 동일합니다. 설치 결과의 차이는 훅뿐이며, Codex의 훅 이벤트
집합에 `Notification`과 `StopFailure`가 없기 때문입니다. Codex 지원 이벤트: `PreToolUse`,
`PermissionRequest`, `PostToolUse`, `PreCompact`, `PostCompact`, `SessionStart`,
`SessionEnd`, `UserPromptSubmit`, `SubagentStart`, `SubagentStop`, `Stop`.

**실행 시점의 차이는 스킬이 스스로 흡수합니다.** 세션 대화 로그를 읽는 스킬
(`my-retro`, `my-daily-log`)은 위 표의 두 경로를 모두 조회합니다. Codex 로그는
프로젝트별로 나뉘지 않으므로 각 파일 첫 줄 `session_meta`의 `payload.cwd`로 걸러야
합니다. 또한 Codex에는 Claude Code의 `Agent` 도구가 없으므로, 서브에이전트에
위임하는 스킬은 도구가 없으면 메인 루프가 같은 절차를 직접 수행합니다 — 위임은
컨텍스트를 아끼기 위한 것이지 절차의 일부가 아닙니다.

## 설치 단계

### 1. skills 디렉토리 생성

`install.sh`가 알아서 만들지만, 수동으로 한다면:

```bash
mkdir -p ~/.claude/skills ~/.codex/skills
```

### 2. 각 skill에 symlink 생성

`skills/` 하위의 각 디렉토리를 타깃의 skills 디렉토리에 symlink로 만듭니다.
판정은 네 갈래입니다:

- 이미 이 저장소를 올바르게 가리킴 → 건너뜀 (`↺`)
- 심링크인데 깨졌거나 다른 경로를 가리킴 → **다시 연결** (`⟳`)
- 실제 디렉토리 → 경고만 하고 보존 (`⚠`)
- 없음 → 생성 (`✓`)

저장소 이름이 바뀌거나 스킬이 이동하면 기존 링크가 깨지는데, `⟳` 분기가 그것을
자동으로 복구합니다. 단순히 `[ -L ]`로 건너뛰면 깨진 링크를 영영 고칠 수 없습니다.

```bash
bash install.sh --target claude   # 또는 codex
```

### 3. MCP 서버 등록

핀 고정된 4종(context7, sequential-thinking, shrimp-task-manager, serena)을
양쪽 타깃에 동일 버전으로 등록합니다.

```bash
bash mcp-install.sh                  # 양쪽
bash mcp-install.sh --target codex   # 한쪽만
```

이미 등록된 서버는 건너뜁니다. 버전을 올리려면 `mcp-install.sh` 상단의 PIN 값을
수정하고, 해당 서버를 remove 한 뒤 다시 실행하세요.

shrimp의 `DATA_DIR` 기본값은 `/Volumes/860QVO/.shrimp-data`입니다. Claude와 Codex가
같은 디렉토리를 공유해야 태스크 목록이 갈라지지 않습니다. 볼륨이 마운트돼 있지 않으면
빈 디렉토리를 만들지 않고 에러로 중단합니다. 다른 위치를 쓰려면:

```bash
SHRIMP_DATA_DIR=/경로 bash mcp-install.sh
```

### 4. 알림음 훅 설치

설정 파일을 통째로 덮지 않고 `hooks`에만 병합하므로, `model`·`statusLine`·기존 훅
(Codex의 `rtk` PreToolUse 등)은 그대로 유지됩니다.

```bash
bash settings/install-sounds.sh        # Claude — 3종
bash settings/install-codex-hooks.sh   # Codex  — Stop 1종
```

훅 정의는 `settings/notification-sounds.json`(Claude)과
`settings/codex-notification-sounds.json`(Codex)에 있습니다.

| 이벤트 | 소리 | 울리는 순간 | Claude | Codex |
|--------|------|-------------|:------:|:-----:|
| `Stop` | Aurora (없으면 Glass) | 응답을 마칠 때 | ✓ | ✓ |
| `Notification` | Ping ×3 + 알림 배너 | 권한 승인 대기 / 60초 이상 유휴 | ✓ | — |
| `StopFailure` | Hero | overloaded·rate_limit 등으로 중단될 때 | ✓ | — |

실행할 때마다 타임스탬프 백업을 남기고, 넣은 훅은 command 끝의
`# my-cc-config:sound` 마커로 식별하므로 **재실행해도 중복되지 않습니다.**

> Aurora는 `ToneLibrary.framework` 내부 파일이라 macOS 업데이트로 경로가 바뀔 수 있습니다.
> 그래서 훅에 폴백이 들어 있어, 파일이 사라지면 조용히 무음이 되지 않고 Glass로 대체 재생됩니다.

> Codex는 `hooks.json`을 해시로 신뢰합니다. 파일을 수정한 뒤 첫 실행에서 재신뢰를
> 요구하면 승인하세요.

### 5. 재시작

skills를 로드하려면 해당 제품(Claude Code / Codex)을 재시작하세요.

## 설치 확인

### 깨진 링크가 없어야 합니다

```bash
for l in ~/.claude/skills/* ~/.codex/skills/* ~/.claude/agents/*; do
  [ -L "$l" ] && { [ -e "$l" ] || echo "BROKEN $l"; }
done
```

아무것도 출력되지 않으면 정상입니다.

### 저장소와 목록이 일치해야 합니다

```bash
diff <(ls skills/) <(ls ~/.claude/skills/ | grep -E "^(my-|goal-maker$)") && echo "claude 일치"
diff <(ls skills/) <(ls ~/.codex/skills/  | grep -E "^(my-|goal-maker$)") && echo "codex 일치"
diff <(ls agents/) <(ls ~/.claude/agents/) && echo "agents 일치"
```

목록을 이 문서에 복제해 두지 않습니다 — 스킬이 추가·삭제될 때마다 어긋나기 때문입니다.

### MCP·훅 확인

```bash
claude mcp list; codex mcp list

jq '.hooks | keys' ~/.claude/settings.json   # Stop, Notification, StopFailure
jq '.hooks | keys' ~/.codex/hooks.json       # Stop (+ 기존 PreToolUse 등)

# 사용자의 기존 훅이 보존됐는지
jq -e '.hooks.PreToolUse[]?.hooks[]? | select(.command == "rtk hook claude")' \
  ~/.codex/hooks.json >/dev/null && echo "rtk 훅 보존됨"
```

## 제거

```bash
# 심링크 — 이 저장소를 가리키는 것만 제거
for dir in ~/.claude/skills ~/.codex/skills; do
  for skill in "$dir"/my-* "$dir"/goal-maker; do
    [ -L "$skill" ] && rm "$skill" && echo "  ✗ $(basename "$skill") removed"
  done
done

# 알림음 훅
bash settings/install-sounds.sh --uninstall
bash settings/install-codex-hooks.sh --uninstall
```

마커가 붙은 훅만 걷어내므로 다른 설정과 훅은 그대로 남습니다.
