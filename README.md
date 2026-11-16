# my-skillset

개인 워크플로우 설정 모음입니다. **Claude Code와 OpenAI Codex 양쪽**에 설치할 수 있습니다.

## 설치

```bash
git clone <repo-url> ~/Projects/my-skillset
bash install.sh                    # Claude Code + Codex 양쪽
bash install.sh --target codex     # 한쪽만
bash install.sh --prune            # 저장소에서 사라진 고아 심링크까지 정리
```

이후 AI agent에게 세팅을 위임하거나, 직접 설치하려면 [`INSTALL.md`](INSTALL.md)를 참고하세요.

> **AI Agent**: 설치 요청을 받으면 `CLAUDE.md`의 "세팅 요청 처리" 섹션을 따르세요.

각 타깃의 skills 디렉토리에 symlink를 생성합니다. 이후 모든 프로젝트에서 `/my-*` 및
`/goal-maker` 커맨드를 사용할 수 있습니다.

### 타깃별 지원 범위

| 항목 | Claude Code | OpenAI Codex |
|------|-------------|--------------|
| 스킬 | `~/.claude/skills` | `~/.codex/skills` |
| MCP 서버 | 2종 (`claude mcp add -s user`) | 2종 (`codex mcp add`) |
| 알림음 훅 | `~/.claude/settings.json` — 3종 | `~/.codex/hooks.json` — **1종(Stop)** |

스킬 포맷과 MCP 핀 버전은 양쪽이 동일합니다. **차이는 훅뿐입니다** — Codex의 훅 이벤트
집합에 `Notification`과 `StopFailure`가 없어 `Stop`만 설치됩니다. Codex가 지원하는 이벤트는
`PreToolUse`, `PermissionRequest`, `PostToolUse`, `PreCompact`, `PostCompact`,
`SessionStart`, `SessionEnd`, `UserPromptSubmit`, `SubagentStart`, `SubagentStop`, `Stop`입니다.

`install.sh`는 재실행해도 안전합니다. 이미 올바르게 걸린 링크는 건드리지 않고, 깨졌거나
옛 경로를 가리키는 링크만 다시 연결합니다.

## 알림음

작업 상태를 소리로 알려주는 훅입니다. 커맨드가 아니라 각 제품의 훅 설정입니다.

| 이벤트 | 소리 | 울리는 순간 | Claude | Codex |
|--------|------|-------------|:------:|:-----:|
| `Stop` | Aurora | 응답을 마칠 때 | ✓ | ✓ |
| `Notification` | Ping ×3 + 알림 배너 | 권한 승인 대기 / 60초 이상 유휴 — 자리를 비워도 놓치지 않도록 | ✓ | — |
| `StopFailure` | Hero | overloaded·rate_limit 등으로 중단될 때 | ✓ | — |

```bash
bash settings/install-sounds.sh                    # Claude 설치 (재실행해도 중복되지 않음)
bash settings/install-sounds.sh --uninstall        # Claude 제거

bash settings/install-codex-hooks.sh               # Codex 설치
bash settings/install-codex-hooks.sh --uninstall   # Codex 제거
```

`install.sh`에 포함되어 있으므로 전체 설치 시 자동으로 적용됩니다. 소리를 바꾸려면
`settings/notification-sounds.json`(Claude) 또는 `settings/codex-notification-sounds.json`(Codex)의
경로를 수정하고 다시 실행하면 됩니다. 사용 가능한 기본 사운드는 `/System/Library/Sounds/`에 있습니다.

두 스크립트 모두 설정 파일을 통째로 덮지 않고 `hooks`에만 병합하며, 자신이 넣은 훅은
`# my-cc-config:sound` 마커로 식별합니다. 사용자의 다른 훅(예: Codex의 `rtk` PreToolUse)은
보존됩니다. Codex는 신뢰 등록되지 않은 훅을 조용히 건너뛰므로, `install.sh`가 마지막에
`settings/trust-codex-hooks.sh`로 이 저장소가 건 훅을 신뢰 등록합니다. `hooks.json`을 고친 뒤에는
이 스크립트를 다시 실행하세요.

## MCP 서버

`mcp-install.sh`가 핀 고정된 2종(context7, shrimp-task-manager)을
양쪽 타깃에 동일 버전으로 등록합니다.

```bash
bash mcp-install.sh                  # 양쪽
bash mcp-install.sh --target codex   # 한쪽만
```

shrimp의 `DATA_DIR`은 기본값이 `/Volumes/860QVO/.shrimp-data`입니다. Claude와 Codex가 같은
디렉토리를 공유해야 태스크 목록이 갈라지지 않기 때문입니다. 볼륨이 마운트돼 있지 않으면
빈 디렉토리를 만들지 않고 에러로 중단합니다. 다른 위치를 쓰려면:

```bash
SHRIMP_DATA_DIR=/경로 bash mcp-install.sh
```

## 커맨드 목록

| 커맨드 | 설명 |
|--------|------|
| `/goal-maker [목표 또는 초안]` | Claude Code/Codex 내장 `/goal` 대상을 자동 판별해 목표글 작성 또는 기존 글의 적합성 판정 |
| `/my-judgment [작업]` | 문제 정의·원인 진단·설계 선택을 AI가 대신 하지 않도록 착수 게이트 → 선택지 제시 → 검증 재료 제공 순으로 대화를 구조화. plan 모드 진입이나 개발 작업 시작 시 **자동 발동**하며, 마무리 시 판단 로그를 `/my-retro`에 넘김 |
| `/my-commit` | 원자성 점검 후 Claude attribution 없는 커밋 작성 |
| `/my-pr [full\|auto]` | 브랜치 변경 분석 후 PR 제목 후보 + body 생성. `full`/`auto` 파라미터 시 GitHub draft PR 자동 생성 + assignee 설정 |
| `/my-retro` | 커밋과 **세션 대화 로그**를 근거로 회고 문서 생성 — 각 항목에 근거 표기, 무엇을 보고 썼는지 명시. 워크트리에서 실행해도 원본 체크아웃 `docs/retro/`에 저장하고 기존 파일 포맷을 승계. 재발 신호만 memory로 승격 (전체 서브에이전트 위임). "작업 마무리하자" 같은 세션 종료 뉘앙스에도 자동 발동 |
| `/my-disk` | 맥 디스크 여유 공간 확인 및 안전한 항목 정리 |
| `/my-daily-log [추가 메모]` | 오늘 Claude Code 대화 로그를 분석하여 Obsidian 일지 초안 생성 |
| `/my-memo [대화 내용]` | 팀원과 나눈 기술/프로젝트 대화를 기반으로 웹 리서치 후 Obsidian 인사이트 메모 생성. 일지의 Reference 섹션에서 wikilink로 연결 가능 |
| `/my-domain-map [주제]` | 도메인 엔티티·데이터 흐름·화면 진입점의 관계도를 조사 → 반증 → 작도 → 아티팩트 발행. 부재·불변식 주장만 골라 검증하고, 그리기 전에 노드 목록을 확인받음 |

### Deprecated

아래 스킬은 저장소에 남아 있지만 **설치되지 않습니다.** 최신 모델(Claude Code Opus 5.5,
Codex luna/terra)의 기본 동작·내장 기능이나 `/my-judgment`와 역할이 겹치기 때문입니다.
`skills/<name>/DEPRECATED` 파일이 표식이며, 지우면 다음 `install.sh` 실행부터 다시 설치됩니다.

| 스킬 | 대체 |
|------|------|
| `my-init` | 내장 `/init` — 심던 파이프라인 표가 deprecated 스킬로 구성됨 |
| `my-interview` | `/my-judgment` 착수 게이트, 모델 기본 확인 질문 |
| `my-plan` | 내장 plan 모드 + `/my-judgment` |
| `my-split` | 내장 plan 모드, `/goal-maker` → `/goal` |
| `my-refine` | plan 모드에서 직접 수정 (`my-split` 전용이었음) |
| `my-iterate` | 리뷰 피드백 직접 전달 (`my-review` 전용이었음) |
| `my-status` | `git status` / `git log` (파이프라인 위치 추정 전용이었음) |
| `my-debug` | `/my-judgment`의 "원인이 미확정인 경우" 절차 |
| `my-check` | Claude `/code-review`·`/simplify`·`/security-review`, Codex `/review` — 존재하지 않는 `code-reviewer` 에이전트에 의존했음 |
| `my-review` | `/my-judgment`, 내장 `/code-review` — 같은 `code-reviewer` 의존 |

## 서브에이전트

Claude Code 전용입니다. `agents/*.md`가 `~/.claude/agents/`로 심링크됩니다.
Codex에는 대응 개념이 없어 설치되지 않습니다.

| 에이전트 | 역할 |
|---------|------|
| `repo-cartographer` | 리포에서 엔티티·쿼리·진입점 관계를 조사해 구조화된 지도로 반환 (읽기 전용) |
| `claim-falsifier` | 부재 주장("X가 없다")과 불변식 주장을 **반증** 시도. 확인이 아니라 깨는 것이 목표 |
| `diagram-author` | 확정된 사실로 인라인 SVG 도면 HTML을 작성하고 경로만 반환. 조사하지 않음 |
| `work-doc-author` | 남에게 넘기는 업무 문서 작성 — 팀 공유 설명·핸드오프·장애 보고·PRD. 조사하지 않음 |
| `dev-middle` | 확정된 명세를 이행. 설계하지 않고, 판단이 필요하면 멈추고 보고 (편집 가능) |
| `dev-senior` | 남이 쓴 변경을 검토해 승인/반려만 판정. **고치지 않음** (읽기 전용) |

`repo-cartographer` 다음 셋은 공통 계약이 있습니다: **조사하지 않고, 확정된 사실만 받아서 만든다.**
조사까지 맡기면 산출물이 그럴듯하게 틀리기 때문입니다. 조사는 `repo-cartographer`가,
검증은 `claim-falsifier`가 맡습니다.

`dev-middle`·`dev-senior`는 **maker-checker** 쌍입니다 — 만든 쪽이 자기 것을 인증하지 않습니다.
모델을 일부러 다르게 뒀고(sonnet/opus), 검토자는 `permissionMode: plan` + 편집 도구 제외로
**구조적으로** 고칠 수 없습니다. LLM이 자기 출력에 더 후한 점수를 준다는 보고가 있어,
격리만으로는 부족하고 모델까지 갈라야 편향이 줄기 때문입니다.

복수 검토는 **독립 → 상호 반박 → 재판정** 순서를 씁니다. 반박 없이 병렬 결과를 합치면
아무도 남의 판정을 시험하지 않아 점수가 부풀려집니다.

`work-doc-author`와 plan 모드의 경계: 계획은 **내가 결정하려고** 쓰는 글,
`work-doc-author`는 **결정이 끝난 뒤 남에게 알리려고** 쓰는 글입니다.

## 표준 작업 플로우

```
(plan 모드 / /goal-maker → /goal) → (구현 + /my-commit 반복) → (내장 리뷰) → /my-pr → /my-retro

└─ /my-judgment ─────────────── 위 전 구간에 걸쳐 자동 적용 ───────────────┘
   (착수 게이트 · 선택지 제시 · 검증 재료 → 마무리 시 /my-retro로 인계)
```

내장 리뷰는 Claude Code `/code-review`·`/simplify`, Codex `/review`입니다.

학습·인사이트 메모는 독립적으로 사용합니다:

```
/my-memo [대화 내용] → Obsidian 메모 생성 → /my-daily-log 일지에서 [[wikilink]] 연결
```

## 문서 저장 구조

skill 실행 시 아래 경로에 자동으로 문서가 생성됩니다.

```
docs/
└── retro/      ← /my-retro 실행 시 저장 (회고 문서 — 폴더가 없으면 만들기 전에 물어봅니다)
```

`docs/plan/`·`docs/review/`는 deprecated된 `my-plan`·`my-review`의 산출물입니다. 기존 파일이
있으면 `/my-retro`가 통합하고 `/my-pr`이 참고하지만, 새로 만들어지지는 않습니다.

## 설계 원칙

탐색·분석이 무거운 skill은 서브에이전트에 위임하여 메인 세션 context를 절약합니다.

| 패턴 | 적용 skill |
|------|-----------|
| 전체 위임 — agent가 모든 작업 수행, 결과만 반환 | `my-retro`, `my-daily-log`, `my-memo` |
| 조사·반증만 위임 — agent가 사실 수집과 반증, 메인 세션이 작도·발행 | `my-domain-map` |
| 메인 세션 직접 실행 — 작업이 가볍거나 사용자 대화 필요 | `goal-maker`, `my-judgment`, `my-commit`, `my-pr`, `my-disk` |

## 구조

```
settings/
├── notification-sounds.json   ← 알림음 훅 정의
└── install-sounds.sh          ← settings.json의 hooks에 병합/제거

agents/                        ← Claude Code 전용, ~/.claude/agents/로 심링크
├── repo-cartographer.md
├── claim-falsifier.md
├── diagram-author.md
├── work-doc-author.md
├── dev-middle.md
└── dev-senior.md

skills/
├── goal-maker/SKILL.md
├── my-judgment/SKILL.md
├── my-commit/SKILL.md
├── my-pr/SKILL.md
├── my-retro/SKILL.md
├── my-disk/SKILL.md
├── my-daily-log/SKILL.md
├── my-memo/SKILL.md
├── my-domain-map/SKILL.md
└── my-{init,interview,plan,split,refine,iterate,status,debug,check,review}/
    ├── SKILL.md
    └── DEPRECATED             ← 있으면 install.sh가 설치하지 않음 (사유·대체 수단 기록)
```
