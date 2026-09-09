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
| MCP 서버 | 4종 (`claude mcp add -s user`) | 4종 (`codex mcp add`) |
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
보존됩니다. Codex는 `hooks.json`을 해시로 신뢰하므로 수정 후 재신뢰를 요구할 수 있습니다.

## MCP 서버

`mcp-install.sh`가 핀 고정된 4종(context7, sequential-thinking, shrimp-task-manager, serena)을
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
| `/my-init [update]` | 현재 프로젝트 CLAUDE.md에 표준 워크플로우 섹션 추가. `update` 인자 시 CLAUDE.md와 README.md를 최신 버전으로 교체 |
| `/my-interview [만들 것]` | 요청이 모호할 때 한 번에 한 질문씩 던져 진짜 의도·성공 기준·제약을 확정 → `/my-plan` 입력으로 인계 |
| `/my-plan [기능명]` | 가정 명시 후 기능 아이디어와 설계 방향 정리 (plan 모드) → `docs/plan/` 저장 |
| `/my-split [auto]` | git branch 생성·전환 후 plan → 주니어 친화적 step별 작업 분해 (수직 슬라이싱·크기 기준). 기본값은 step 완료마다 사용자 확인 대기, `auto` 인자 시 자동 진행 |
| `/my-commit` | 원자성 점검 후 Claude attribution 없는 커밋 작성 |
| `/my-debug [증상]` | 테스트·빌드 실패를 재현 → 국소화 → 근본 원인 → 재발 방지 순으로 해결 |
| `/my-check` | 타입·린트·테스트·빌드 검증 후 5축(정확성·가독성·구조·성능·보안) 코드 리뷰 (분석은 서브에이전트 위임) |
| `/my-pr [full\|auto]` | 브랜치 변경 분석 후 PR 제목 후보 + body 생성. `full`/`auto` 파라미터 시 GitHub draft PR 자동 생성 + assignee 설정 |
| `/my-review [피드백]` | 코드 리뷰 피드백 분류 및 적용 (분류 분석은 서브에이전트 위임) → `docs/review/` 저장 |
| `/my-iterate [auto]` | 리뷰 피드백 기반 개선 작업을 step별로 분해. my-review 이후 사용 |
| `/my-retro` | 커밋과 **세션 대화 로그**를 근거로 회고 문서 생성 — 각 항목에 근거 표기, 무엇을 보고 썼는지 명시. 워크트리에서 실행해도 원본 체크아웃 `docs/retro/`에 저장하고 기존 파일 포맷을 승계. 재발 신호만 memory로 승격 (전체 서브에이전트 위임). "작업 마무리하자" 같은 세션 종료 뉘앙스에도 자동 발동 |
| `/my-status` | 현재 워크플로우 위치 파악 — 브랜치·문서 현황·미커밋 변경사항·다음 권장 단계 |
| `/my-disk` | 맥 디스크 여유 공간 확인 및 안전한 항목 정리 |
| `/my-daily-log [추가 메모]` | 오늘 Claude Code 대화 로그를 분석하여 Obsidian 일지 초안 생성 |
| `/my-memo [대화 내용]` | 팀원과 나눈 기술/프로젝트 대화를 기반으로 웹 리서치 후 Obsidian 인사이트 메모 생성. 일지의 Reference 섹션에서 wikilink로 연결 가능 |
| `/my-domain-map [주제]` | 도메인 엔티티·데이터 흐름·화면 진입점의 관계도를 조사 → 반증 → 작도 → 아티팩트 발행. 부재·불변식 주장만 골라 검증하고, 그리기 전에 노드 목록을 확인받음 |
| `/my-refine [피드백]` | 기획 단계(plan/step)에 대한 피드백 반영. `my-split` 결과물 수정 시 사용 |

## 표준 작업 플로우

```
(/my-interview) → /my-plan → /my-split → (구현 + /my-commit 반복) → /my-check → /my-pr
   (요청 모호할 때)              ↓              ↓                                    ↓
                            /my-refine     /my-debug          /my-retro ← /my-iterate ← /my-review
                            (step 수정)    (실패 시)
```

학습·인사이트 메모는 독립적으로 사용합니다:

```
/my-memo [대화 내용] → Obsidian 메모 생성 → /my-daily-log 일지에서 [[wikilink]] 연결
```

새 프로젝트 시작 시 `/my-init`, 워크플로우가 바뀌었을 때는 `/my-init update`를 실행하면 됩니다.

## 문서 저장 구조

skill 실행 시 아래 경로에 자동으로 문서가 생성됩니다.

```
docs/
├── plan/       ← /my-plan 승인 후 저장 (기획 방향)
├── review/     ← /my-review 완료 후 저장 (피드백 이력)
└── retro/      ← /my-retro 실행 시 저장 (회고 문서 — 폴더가 없으면 만들기 전에 물어봅니다)
```

## 설계 원칙

탐색·분석이 무거운 skill은 서브에이전트에 위임하여 메인 세션 context를 절약합니다.

| 패턴 | 적용 skill |
|------|-----------|
| 전체 위임 — agent가 모든 작업 수행, 결과만 반환 | `my-retro`, `my-daily-log`, `my-memo` |
| 부분 위임 — agent가 분석, 메인 세션이 수정 적용 | `my-check`, `my-review`, `my-debug` |
| 조사·반증만 위임 — agent가 사실 수집과 반증, 메인 세션이 작도·발행 | `my-domain-map` |
| 메인 세션 직접 실행 — 작업이 가볍거나 plan mode·사용자 대화 필요 | `my-init`, `my-interview`, `my-plan`, `my-split`, `my-iterate`, `my-commit`, `my-pr` |

## 구조

```
settings/
├── notification-sounds.json   ← 알림음 훅 정의
└── install-sounds.sh          ← settings.json의 hooks에 병합/제거

skills/
├── goal-maker/SKILL.md
├── my-init/SKILL.md
├── my-interview/SKILL.md
├── my-plan/SKILL.md
├── my-split/SKILL.md
├── my-commit/SKILL.md
├── my-debug/SKILL.md
├── my-check/SKILL.md
├── my-pr/SKILL.md
├── my-review/SKILL.md
├── my-iterate/SKILL.md
├── my-retro/SKILL.md
├── my-refine/SKILL.md
├── my-status/SKILL.md
├── my-disk/SKILL.md
├── my-daily-log/SKILL.md
├── my-memo/SKILL.md
└── my-domain-map/SKILL.md
```
