# my-skillset — Agent Guide

## 프로젝트 개요

개인 워크플로우 스킬 모음. `skills/*/` 디렉토리를 각 제품의 skills 디렉토리에 symlink로
연결해 전역 커맨드로 사용할 수 있게 합니다. **Claude Code(`~/.claude/skills`)와
OpenAI Codex(`~/.codex/skills`) 양쪽**을 지원합니다.

## 세팅 요청 처리

사용자가 다음과 같은 요청을 하면 **아래 설치 절차를 직접 실행**하세요:

- "이 프로젝트 세팅해줘"
- "README.md, CLAUDE.md 파악해서 설치해줘"
- "처음 설치하는데 도와줘"
- 그 외 초기 설정 관련 요청

### 설치 절차

**Step 1** — `install.sh`를 실행하세요. 절차를 손으로 재현하지 말고 이 스크립트를 쓰세요.

```bash
bash install.sh              # Claude Code + Codex 양쪽
bash install.sh --target codex   # 한쪽만
```

스크립트가 하는 일: 타깃별 skills 디렉토리 생성 → 심링크 연결(깨졌거나 옛 경로를 가리키는
링크는 자동 재연결) → MCP 4종 등록 → 알림음 훅 병합. 전부 멱등이라 재실행해도 안전합니다.

**Step 2** — 고아 심링크가 보고되면 사용자에게 목록을 보여주고 확인을 받으세요.

저장소에서 사라진 스킬의 링크는 기본적으로 **목록만 출력하고 삭제하지 않습니다.**
사용자가 동의하면 그때 `bash install.sh --prune`을 실행하세요. 확인 없이 삭제하지 않습니다.

**Step 3** — 완료 후 해당 제품(Claude Code / Codex) 재시작을 안내하세요.

**Step 4** — 설치 확인:

```bash
# 깨진 링크가 없어야 한다 (출력 없으면 정상)
for l in ~/.claude/skills/* ~/.codex/skills/*; do
  [ -L "$l" ] && { [ -e "$l" ] || echo "BROKEN $l"; }
done

diff <(ls skills/) <(ls ~/.claude/skills/ | grep -E "^(my-|goal-maker$)") && echo "claude 일치"
diff <(ls skills/) <(ls ~/.codex/skills/  | grep -E "^(my-|goal-maker$)") && echo "codex 일치"

jq '.hooks | keys' ~/.claude/settings.json   # Stop, Notification, StopFailure
jq '.hooks | keys' ~/.codex/hooks.json       # Stop (+ 기존 PreToolUse 보존)
```

### 주의사항

- **설정 파일을 통째로 덮지 마세요.** `~/.claude/settings.json`에는 `model`·`statusLine` 등이,
  `~/.codex/hooks.json`에는 사용자의 `rtk` PreToolUse 훅이 들어 있습니다. 반드시
  `settings/install-sounds.sh` / `settings/install-codex-hooks.sh`를 쓰세요 — 백업을 남기고
  `# my-cc-config:sound` 마커가 붙은 훅만 교체합니다.
- **Codex에는 Stop 알림음만 설치됩니다.** Codex의 훅 이벤트 집합에 `Notification`과
  `StopFailure`가 없습니다. 이것은 버그가 아니라 제품 제약입니다.
- **shrimp `DATA_DIR`은 Claude와 Codex가 같은 값을 써야 합니다**(기본
  `/Volumes/860QVO/.shrimp-data`). 갈라지면 태스크 목록이 둘로 나뉩니다. 볼륨이 없으면
  `mcp-install.sh`가 빈 디렉토리를 만들지 않고 중단합니다.
- **워크트리에서 `install.sh`를 실행하지 마세요.** 심링크가 워크트리 경로를 가리키게 되어
  워크트리를 제거하면 전부 깨집니다. 항상 메인 체크아웃에서 실행하세요.

세부 사항은 [`INSTALL.md`](INSTALL.md)를 참조하세요.

## 사용 가능한 커맨드

| 커맨드 | 설명 |
|--------|------|
| `/goal-maker [목표 또는 초안]` | Claude Code/Codex 내장 `/goal` 대상을 자동 판별해 목표글 작성 또는 기존 글의 적합성 판정 |
| `/my-init [update]` | 현재 프로젝트 CLAUDE.md에 표준 워크플로우 섹션 추가 |
| `/my-interview [만들 것]` | 요청이 모호할 때 한 질문씩 던져 의도·성공 기준·제약 확정 |
| `/my-plan [기능명]` | 가정 명시 후 설계 방향·리스크 정리 → `docs/plan/` 저장 |
| `/my-split [auto]` | plan → 수직 슬라이스 단위 step별 작업 분해 |
| `/my-commit` | 원자성 점검 후 Claude attribution 없는 커밋 |
| `/my-debug [증상]` | 테스트·빌드 실패를 근본 원인 기반으로 해결 |
| `/my-check` | 타입·린트·테스트·빌드 검증 후 5축 코드 리뷰 |
| `/my-pr` | PR 제목 추천 |
| `/my-review [피드백]` | 코드 리뷰 피드백 분류 및 적용 |
| `/my-iterate [auto]` | 리뷰 피드백 기반 개선 작업 분해 |
| `/my-retro` | 커밋 + 세션 대화 로그 기반 회고 문서 생성, 재발 신호는 memory 승격 (세션 마무리 뉘앙스에 자동 발동) |
| `/my-status` | 현재 워크플로우 위치 파악 |
| `/my-refine [피드백]` | 기획 단계(plan/step) 피드백 반영 |
| `/my-daily-log [메모]` | 오늘 대화 로그 분석 후 Obsidian 일지 초안 생성 |
| `/my-memo [대화 내용]` | 대화 기반 웹 리서치 후 Obsidian 인사이트 메모 저장 |
| `/my-domain-map [주제]` | 도메인 관계도를 조사 → 반증 → 작도 → 아티팩트 발행 (부재·불변식 주장만 검증) |
| `/my-disk` | 맥 디스크 여유 공간 확인 및 정리 |
