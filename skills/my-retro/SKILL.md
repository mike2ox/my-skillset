---
name: my-retro
description: 브랜치 커밋과 세션 대화를 근거로 회고 문서를 만들고, 다시 걸릴 함정만 memory로 승격합니다. 비개발직군도 읽을 수 있는 형식입니다. 사용자가 "작업 마무리하자", "이번 작업 끝내자", "세션 정리하자"처럼 작업을 마무리하는 뉘앙스로 말할 때도 사용하세요.
argument-hint: [--output <파일-경로>]
allowed-tools: Agent AskUserQuestion Read(*) Write(*) Bash(git *) Bash(ls *) Bash(find *) Bash(mkdir *) Bash(mv *) Bash(python3 *) Bash(date *)
---

`$ARGUMENTS` 맨 앞의 선택적 `--output <파일-경로>`를 먼저 처리하고 제거한 나머지 인자를 사용합니다. 공백이 있는 경로는 인용합니다.

## 출력 경로 옵션

- `--output`은 **파일 경로**만 받습니다. 상대 경로는 현재 프로젝트 디렉터리 기준으로 해석하며, 디렉터리만 넘기면 올바른 파일 경로를 AskUserQuestion으로 다시 받습니다.
- `--output`이 있으면 회고 산출물은 그 정확한 경로에 저장합니다. 상위 디렉터리가 없으면 임의로 만들지 말고, 생성 / 다른 경로 지정 / 저장 취소 중 하나를 AskUserQuestion으로 묻습니다.
- 지정한 파일이 이미 있으면 자동으로 덮어쓰지 말고, 덮어쓰기 / 다른 파일 경로 / 저장 취소 중 하나를 AskUserQuestion으로 묻습니다.
- `--output`이 없을 때는 아래의 원본 체크아웃·기본 회고 폴더 탐색·파일명 규칙을 그대로 적용합니다.

브랜치 작업의 회고 문서를 만들고, 재발 신호만 memory로 승격합니다. 본 작업은 Agent tool로 위임합니다.

## 위임 전 확인 (메인 루프)

### 1. 회고할 작업이 있는가

기준 브랜치를 먼저 정합니다. `main` 고정이 아닙니다 — 리포마다 개발 브랜치가 다릅니다.

```bash
git branch --show-current
git ls-remote --heads origin | sed 's|.*refs/heads/||'
```

`origin/development` → `origin/develop` → `origin/dev` → `origin/main` 순으로 **정확히 일치하는** 첫 이름을 기준(`BASE`)으로 삼습니다. 접두어 매칭으로 줄여 쓰지 않습니다. 이후 모든 git 명령에서 `main` 대신 이 `BASE`를 씁니다.

```bash
git log $BASE..HEAD --oneline
```

- 기준 브랜치 위에 있거나 커밋이 없으면 위임하지 않습니다. "회고할 작업 내역이 없습니다"라고 알리고 종료합니다.
- 이 스킬은 파일을 **삭제하지 않습니다.** 원본 plan/review 문서는 아카이브로 옮길 뿐이므로 되돌릴 수 있습니다.

### 2. 어디에 남길 것인가 — 워크트리면 원본 체크아웃

`--output`이 없을 때 워크트리 안에 회고를 쓰면 워크트리를 제거할 때 함께 사라지고, memory 경로도 원본 프로젝트와 갈라집니다. 따라서 기본 회고는 **항상 원본 체크아웃에 씁니다.** `--output`이 있으면 회고 파일만 그 지정 경로에 쓰되, memory와 plan/review 통합·아카이브의 기준은 계속 원본 체크아웃으로 유지합니다.

```bash
git rev-parse --git-common-dir    # .../<원본>/.git 이면 그 상위가 원본 체크아웃
```

- 산출물 회고 → `--output`이 있으면 지정 파일 경로, 없으면 `<원본 체크아웃>/docs/retro/`
- memory → `~/.claude/projects/<mangled>/memory/` — `<mangled>`는 **원본 체크아웃 절대경로**의 `/`·공백·`.`를 모두 `-`로 바꾼 문자열입니다. 워크트리 경로로 만들면 메모리가 원본과 갈라집니다.

`--output`이 없고 워크트리에서 실행했다면 완료 보고에 "워크트리가 아니라 `<경로>`에 저장했습니다"를 반드시 적습니다. `--output`이 있으면 지정 경로를 그대로 보고합니다.

### 3. 저장 공간이 있는가

`--output`이 있으면 위에서 지정 파일의 상위 디렉터리를 확인했으므로 이 기본 저장 폴더 탐색을 건너뜁니다. 없으면 `<원본 체크아웃>/docs/retro/`가 없을 때 `docs/retrospective/`, `docs/` 순으로 찾습니다. 하나도 없으면 **만들지 말고** AskUserQuestion으로 묻습니다: "이 프로젝트엔 회고 폴더가 없습니다. `docs/retro/`를 만들까요?" 선택지는 `docs/retro/ 생성`, `다른 경로 지정`, `이번엔 만들지 않음 — 스크래치패드에 쓰고 경로만 안내`.

### 4. 스코프 선택

AskUserQuestion으로 한 번 묻습니다: "회고 근거를 어디까지 볼까요?"

- **커밋 + 세션 대화 (권장)** — 커밋·plan·review에 더해 이 작업 기간의 대화 로그까지 읽습니다. "왜 그렇게 판단했나"가 남는 유일한 경로입니다.
- **커밋만** — git과 `docs/` 문서만 봅니다. 빠르지만 의사결정 기록은 대부분 비게 됩니다.

선택 결과를 `SCOPE`로 에이전트에 전달합니다.

## 실행 환경 판별 — Claude Code / Codex

세션 대화 로그의 위치와 형식이 제품마다 다릅니다. `SCOPE`가 "커밋만"이면 이 절을 건너뜁니다.

| | Claude Code | OpenAI Codex |
|---|---|---|
| 로그 위치 | `~/.claude/projects/<mangled>/*.jsonl` | `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` |
| 프로젝트 구분 | 디렉토리명이 곧 프로젝트 | 구분 없음 — 파일 첫 줄 `session_meta`의 `payload.cwd`로 걸러야 함 |
| 유저 발화 | `.type=="user"` → content의 `text` 블록 | `payload.type=="message"`, `role=="user"` → content의 `input_text` |
| 어시스턴트 발화 | `.type=="assistant"` → content의 `text` 블록 | `payload.type=="message"`, `role=="assistant"` → content의 `output_text` |
| 버릴 것 | `tool_use`·`thinking` 블록, `isMeta` 항목 | `reasoning`·`custom_tool_call`·`function_call` 항목, `developer` 역할 |

판별 순서:

1. 현재 실행 중인 제품이 명확하면 그것을 씁니다.
2. 불명확하면 두 경로를 모두 조회해, 이 작업 기간에 수정된 로그가 있는 쪽을 씁니다.
3. 양쪽에 다 있으면 양쪽을 모두 읽습니다 — 한 작업을 두 제품에서 이어서 한 경우입니다.
4. 어느 쪽도 없으면 대화 근거 없이 진행하고, 그 사실을 커버리지에 적습니다.

## Agent 위임

Agent tool을 호출하세요. 파라미터:
- description: "브랜치 회고 문서 생성"
- prompt: 아래 내용 + `BASE`, `SCOPE`, 확정된 회고 저장 파일 경로(또는 기본 저장 폴더), memory 경로, 판별한 로그 경로

**Agent tool이 없는 환경(Codex 등)에서는 메인 루프가 아래 절차를 그대로 직접 수행합니다.** 위임은 컨텍스트를 아끼기 위한 것이지 절차의 일부가 아닙니다.

---
현재 브랜치의 작업 내용을 분석하여 회고 문서를 작성합니다.

아래 명령을 실행하여 정보를 수집하세요 (`$BASE`는 전달받은 기준 브랜치):
- git branch --show-current
- git log $BASE..HEAD --oneline
- git log $BASE..HEAD --format="%ai %s"
- git diff $BASE...HEAD --stat
- git diff $BASE...HEAD (주요 변경 파악용)
- git config user.name

---

## 0단계: plan/review 파일 통합 및 아카이브

**원본 파일을 삭제하지 않습니다.** 통합본을 만든 뒤 원본은 `_archive/` 하위로 옮깁니다. 삭제는 되돌릴 수 없지만 이동은 되돌릴 수 있습니다.

### docs/plan/ 통합

`docs/plan/` 파일이 2개 이상이면:

1. 모든 plan 파일을 날짜순으로 읽습니다
2. `docs/plan/{브랜치명}-merged.md`로 통합합니다:

```markdown
# [기능명] 통합 기획서

## 최종 기획 방향
(가장 최신 plan 파일의 핵심 내용 — 기능 개요, 사용자 스토리, 기술적 접근 방향)

## 기획 변경 이력
| 날짜 | 원본 파일 | 주요 변경 |
|------|----------|---------|
| {날짜} | {원본 파일명} | {초기 방향 요약} |
```

3. 원본 파일들을 `docs/plan/_archive/`로 **이동**합니다 (`mkdir -p docs/plan/_archive && mv ...`). 통합본은 `docs/plan/` 최상위에 남깁니다.

파일이 1개 이하이면 이 단계를 건너뜁니다.

### docs/review/ 통합

`docs/review/` 파일이 2개 이상이면 같은 방식으로 처리합니다.

1. 날짜순으로 읽어 `docs/review/{브랜치명}-merged.md`로 통합
2. 아래 형식 사용:

```markdown
# [기능명] 통합 리뷰 이력

## 리뷰 요약 테이블
| 회차 | 날짜 | 필수 수정 | 권장 개선 | 선택 제안 | 적용률 |
|------|------|---------|---------|---------|------|
| 1차 | {날짜} | {N}건 | {N}건 | {N}건 | {N}/{총}건 |

## 리뷰 상세
### 1차 리뷰 — {날짜}
(원본 review 파일 내용)
```

3. 원본 파일들을 `docs/review/_archive/`로 **이동**합니다.

파일이 1개 이하이면 이 단계를 건너뜁니다.

---

## 1단계: 세션 대화 로그 수집

`SCOPE`가 "커밋만"이면 이 단계를 건너뛰고, 커버리지에 "세션 대화 미조회 — 사용자가 커밋만 선택"이라고 적습니다.

### 대상 세션 고르기

브랜치 첫 커밋 시각 이후에 수정된 로그만 봅니다. 그 이전은 이 작업과 무관합니다.

```bash
SINCE=$(git log $BASE..HEAD --format=%ai | tail -1 | cut -c1-10)
```

- Claude Code: `~/.claude/projects/<mangled>/*.jsonl` 중 `-newermt "$SINCE"`. 워크트리에서 작업했다면 워크트리 경로의 mangled 디렉토리에도 로그가 있으므로 **양쪽 다** 봅니다.
- Codex: `~/.codex/sessions/**/rollout-*.jsonl` 중 `-newermt "$SINCE"` **이면서** 첫 줄 `session_meta`의 `payload.cwd`가 이 프로젝트(워크트리 경로 포함)인 것

### 대화만 추출

도구 호출·결과·추론은 버리고 **양쪽 화자의 실제 발화만** 남깁니다. Claude Code에서 tool_result는 `user` 타입으로 들어오므로 타입만 보고 거르면 수십 MB가 딸려옵니다. 아래 스크립트를 스크래치패드에 저장해 실행합니다.

```python
import json, sys, pathlib

NOISE = ("<command-", "<system-reminder", "<local-command",
         "<app-context", "<recommended_plugins", "<user-prompt-submit")

def texts(blocks, kinds):
    out = []
    for b in blocks if isinstance(blocks, list) else []:
        if isinstance(b, dict) and b.get("type") in kinds:
            t = (b.get("text") or "").strip()
            if t:
                out.append(t)
    return "\n".join(out)

def claude(o):
    if o.get("isMeta"):
        return None
    msg = o.get("message") or {}
    content = msg.get("content")
    if o.get("type") == "user":
        body = content if isinstance(content, str) else texts(content, {"text"})
        return ("USER", body)
    if o.get("type") == "assistant":
        return ("ASSISTANT", texts(content, {"text"}))
    return None

def codex(o):
    if o.get("type") != "response_item":
        return None
    p = o.get("payload") or {}
    if p.get("type") != "message":
        return None
    if p.get("role") == "user":
        return ("USER", texts(p.get("content"), {"input_text"}))
    if p.get("role") == "assistant":
        return ("ASSISTANT", texts(p.get("content"), {"output_text"}))
    return None          # developer 역할은 시스템 주입이므로 제외

parse = claude if sys.argv[1] == "claude" else codex
for path in sys.argv[2:]:
    print(f"\n===== {path} =====")
    for raw in pathlib.Path(path).read_text(errors="replace").splitlines():
        if not raw.strip():
            continue
        try:
            got = parse(json.loads(raw))
        except Exception:
            continue
        if not got:
            continue
        who, text = got[0], (got[1] or "").strip()
        if not text or text.startswith(NOISE):
            continue
        print(f"\n{who}: {text}")
```

`python3 extract.py claude <파일들>` 또는 `python3 extract.py codex <파일들>`로 실행합니다. 수 MB짜리 세션이 보통 수백 KB의 대화로 줄어듭니다.

결과를 스크래치패드에 저장한 뒤 **전문을 읽습니다.** 키워드로 검색하지 않습니다 — 찾는 것이 "판단의 흔적"이라 어떤 단어로 나타날지 미리 알 수 없습니다.

### 무엇을 찾는가

| 대화에서 찾을 신호 | 회고의 어느 칸으로 가는가 |
|---|---|
| 최초 증상 진술, 로그·지표 언급, "이거 왜 이래요" | ① 문제를 어떻게 알게 됐나 |
| 방향 전환, "그건 아니고", 되돌린 결정 | ③ 의사결정 기록 — **버린 길** |
| 두 번 이상 걸린 함정, 반복된 교정 | ③ + 3단계 memory 승격 후보 |
| 범위를 줄인 합의 ("이번엔 여기까지") | ③ 의사결정 기록 |
| 정리·리팩터링을 먼저 하기로 한 대화 | ② 정리 먼저 |

사용자 발화만 보지 않습니다. 어시스턴트가 제안해 채택된 판단도 그대로 의사결정이며, 그 근거는 어시스턴트 쪽 발화에만 남아 있는 경우가 많습니다.

### 실패해도 멈추지 않습니다

로그를 못 찾거나 파싱이 실패하거나 대상 세션이 0개이면 **중단하지 말고** 커밋 근거만으로 계속 진행합니다. 사유는 커버리지에 남깁니다. 회고가 아예 안 나오는 것보다 근거가 얕은 회고가 낫고, 얕다는 사실을 밝히면 독자가 판단할 수 있습니다.

## 2단계: 회고 문서 작성

0단계 완료 후 `docs/plan/`과 `docs/review/`의 (통합된) 문서를 읽고, 1단계에서 모은 대화 근거와 함께 반영합니다.

`--output`이 있으면 파일명·확장자·저장 위치는 메인 루프가 전달한 그 파일 경로를 그대로 사용합니다. 없으면 파일명은 `YYYY-MM-DD-{브랜치명}`, 확장자는 아래 "기존 포맷을 따릅니다"에서 정하고, 저장 위치는 메인 루프가 전달한 기본 경로(**워크트리가 아니라 원본 체크아웃의 회고 폴더**)입니다. 폴더를 임의로 만들지 않습니다 — 없을 때의 처리는 메인 루프가 이미 사용자에게 확인했습니다.

### 읽는 사람

**주니어 개발자와 비개발직군이 첫 독자입니다.** 이 사람들은 코드를 보지 않았고, 브랜치명이나 함수명도 모릅니다.

- 문서 맨 위 "한 줄 요약"과 "왜 했나"만 읽고도 무슨 일이 있었는지 알 수 있어야 합니다.
- 기술 용어를 쓰면 **용어 풀이 표**에 일상어로 한 줄 설명을 답니다. (예: "마이그레이션 — 기존 데이터를 새 구조로 옮기는 작업")
- 약어, 화살표 연쇄(`A → B → 실패`), 작업 중에 만든 별칭을 쓰지 않습니다. 완전한 문장으로 씁니다.
- 상세 기술 내용은 지우지 말고 **뒤쪽 섹션으로** 보냅니다. 앞은 요약, 뒤는 근거입니다.

### 결과가 아니라 과정을 적는 세 섹션

무엇을 만들었는지는 diff에 남지만, **왜 그렇게 판단했는지는 아무 데도 남지 않습니다.** 아래 세 섹션이 그 기록입니다. 추측으로 채우지 말고, 근거를 못 찾으면 그 행을 비워 두거나 섹션째로 삭제합니다.

**① 문제를 어떻게 알게 됐나** — 기능을 만들기로 한 판단의 출발점입니다.

- 최초 신호가 무엇이었는지: 문의, 오류 로그, 지표 변화, 직접 관찰 중 어느 것이었나
- 그 신호를 확인하려고 무엇을 했고, 그 결과 범위가 어떻게 좁혀졌나
- 한 번의 사건인지 반복되는 문제인지 무엇으로 판단했나
- 근거를 찾을 곳: `docs/plan/`의 문제 정의, 브랜치 첫 커밋 이전의 대화, 연결된 이슈

**② 정리 먼저 — 고치기 전에 치운 것** — 동작을 바꾸지 않는 정리(이름 변경, 추출, 중복 제거, 위치 이동)와 동작을 바꾸는 변경을 나눠 적습니다.

- 커밋 메시지에서 `refactor:` `chore:` `style:`과 `feat:` `fix:`를 구분해 찾습니다
- 각 정리에 **"이 정리가 없었으면 다음 작업이 왜 어려웠는지"**를 씁니다. 그 이유를 못 쓰겠다면 필요 없던 정리였을 수 있으니 그렇게 적습니다
- 정리와 기능이 한 커밋에 섞여 있었다면 **그것도 사실대로 적습니다.** 다음 작업에서 고칠 지점입니다
- 정리 커밋이 하나도 없으면 이 섹션째로 삭제합니다

**③ 의사결정 기록** — 갈림길마다 무엇을 고르고 무엇을 버렸는지입니다.

- 코드에 흔적이 남는 결정(규칙, 저장 구조, 계산 시점)뿐 아니라 **범위를 줄인 결정**도 포함합니다
- **"버린 길과 이유"가 이 표의 핵심입니다.** 고른 것만 적으면 나중에 같은 고민을 처음부터 다시 하게 됩니다
- "되돌리기"는 이 결정을 나중에 무르는 비용입니다. 함수 한 곳이면 쉬움, 이미 저장된 데이터 구조가 걸리면 어려움
- 근거를 찾을 곳: `docs/review/`의 판단 기록, 리뷰에서 뒤집힌 항목, plan의 "안 할 것"

### 기존 포맷을 따릅니다

`--output`이 없으면 저장 폴더에서 **가장 최근 회고 파일 1개를 읽고** 그 확장자와 섹션 구조를 그대로 씁니다. 한 폴더 안에서 형식이 갈라지지 않게 하는 것이 목적입니다. `--output`이 있으면 지정한 파일의 확장자가 `.md`인지 `.html`인지 확인해 그 형식으로 쓰고, 다른 확장자면 AskUserQuestion으로 `.md` 또는 `.html` 파일 경로를 다시 받습니다.

- 기본 저장에서 최근 파일이 `.md`이면 마크다운으로 씁니다. 아래 HTML 골격은 쓰지 않습니다.
- 기본 저장에서 최근 파일이 `.html`이면 아래 골격을 씁니다.
- 기본 저장에서 폴더가 비어 있으면 아래 HTML 골격이 기본값입니다.
- `--output` 저장에서는 지정 경로의 `.md` 또는 `.html` 확장자에 맞는 위 형식을 씁니다.

기존 파일에 이 스킬이 정하지 않은 섹션이 있으면 그것도 따릅니다. 반대로 아래 세 섹션(①②③)은 기존 포맷에 없더라도 **추가합니다** — 이 회고의 존재 이유이기 때문입니다.

### 근거를 함께 적습니다

①②③의 각 항목 끝에 근거를 답니다. 근거 없는 문장은 회고가 아니라 추측입니다.

- `근거: 커밋 abc1234` / `근거: 대화 2026-08-28` / `근거: docs/plan/foo.md` 중 **실제로 확인한 것**만 씁니다.
- 정황으로 미루어 쓴 것에는 `(추정)`을 붙입니다. **추정이 근거보다 많은 섹션은 통째로 삭제합니다.**
- 한 항목을 커밋과 대화가 함께 뒷받침하면 둘 다 나열합니다. 두 곳 이상에서 확인된 항목이 이 회고에서 가장 믿을 만한 부분입니다.

### 무엇을 보고 썼는지 밝힙니다

문서 첫 화면에 "이 회고가 본 것" 블록을 넣습니다. 안 본 것을 적지 않으면 독자는 다 봤다고 읽습니다.

- 커밋 N개 — 전부 읽었는지 일부인지
- `docs/plan/` M건, `docs/review/` K건
- 세션 대화 P개와 그 기간. 보지 않았다면 사유 — "사용자가 커밋만 선택", "로그를 찾지 못함", "추출 실패"
- 이 회고가 다루지 않는 범위 — 기준 브랜치 이전 이력, 다른 브랜치의 관련 작업 등
### HTML 요구사항

폴더가 비어 있거나 최근 파일이 `.html`일 때 적용합니다. 마크다운 폴더에서는 아래 골격 대신 같은 내용을 기존 마크다운 구조로 씁니다.

- **자체 완결**: CSS를 `<style>`에 인라인. 외부 폰트·스크립트·이미지를 참조하지 않습니다 (사내망·오프라인에서도 열려야 함).
- **라이트/다크 양쪽 대응**: 모든 색을 `:root` 토큰으로 정의하고, 다크에서는 **토큰 값만** 교체합니다. 색을 미디어 쿼리 안에서만 정의하면 한쪽 테마에서 글자가 안 보입니다. `body`에는 배경색을 명시적으로 지정합니다.
- **표는 가로 스크롤**: 표를 `overflow-x: auto` 컨테이너로 감싸 본문이 가로로 밀리지 않게 합니다.
- `<title>`은 `{기능명} 작업 회고`.

아래 골격을 그대로 사용하고 `{}` 자리만 채웁니다.

```html
<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{기능명} 작업 회고</title>
<style>
  :root {
    --paper: #f6f5f2; --card: #ffffff; --ink: #1c1e23; --muted: #6a6e75; --line: #e2e0da;
    --accent: #2f6b5f; --accent-bg: #e6efec;
    --sev-high: #a8412a; --sev-mid: #8f6518; --sev-low: #6a6e75;
  }
  @media (prefers-color-scheme: dark) {
    :root:not([data-theme="light"]) {
      --paper: #15171a; --card: #1c1f24; --ink: #e6e5e1; --muted: #9a9da4; --line: #2b2e34;
      --accent: #6fbfa9; --accent-bg: #1c2b28;
      --sev-high: #e08a72; --sev-mid: #d6a54a; --sev-low: #9a9da4;
    }
  }
  :root[data-theme="dark"] {
    --paper: #15171a; --card: #1c1f24; --ink: #e6e5e1; --muted: #9a9da4; --line: #2b2e34;
    --accent: #6fbfa9; --accent-bg: #1c2b28;
    --sev-high: #e08a72; --sev-mid: #d6a54a; --sev-low: #9a9da4;
  }
  *, *::before, *::after { box-sizing: border-box; }
  body {
    margin: 0; padding: 3.5rem 1.5rem 4rem;
    background: var(--paper); color: var(--ink);
    font-family: "Apple SD Gothic Neo", Pretendard, "Malgun Gothic", "Noto Sans KR", -apple-system, BlinkMacSystemFont, sans-serif;
    font-size: 16px; line-height: 1.75; word-break: keep-all; overflow-wrap: anywhere;
    -webkit-font-smoothing: antialiased;
  }
  .doc { max-width: 44rem; margin: 0 auto; display: flex; flex-direction: column; gap: 2.75rem; }
  .head { display: flex; flex-direction: column; gap: .75rem; }
  h1 { font-size: clamp(1.6rem, 1.2rem + 1.6vw, 2.1rem); font-weight: 700; letter-spacing: -.022em; line-height: 1.3; text-wrap: balance; margin: 0; }
  .rule { display: flex; gap: 2px; height: 6px; }
  .rule i { flex: 1; background: var(--line); border-radius: 1px; }
  .rule i.on { flex: 0 0 7px; background: var(--ink); opacity: .5; }
  .meta { color: var(--muted); font-size: .875rem; line-height: 1.6; display: flex; flex-wrap: wrap; gap: .3rem .9rem; }
  .meta span { white-space: nowrap; }
  .summary { background: var(--card); border: 1px solid var(--line); border-left: 3px solid var(--accent); border-radius: 2px; padding: 1.4rem 1.5rem; display: flex; flex-direction: column; gap: 1rem; }
  .summary > div { display: flex; flex-direction: column; gap: .15rem; }
  .summary dt { font-size: .7rem; font-weight: 700; letter-spacing: .1em; color: var(--accent); }
  .summary dd { margin: 0; font-size: 1.02rem; line-height: 1.7; }
  section { display: flex; flex-direction: column; gap: .85rem; }
  h2 { font-size: 1.08rem; font-weight: 700; letter-spacing: -.012em; margin: 0; padding-bottom: .5rem; border-bottom: 1px solid var(--line); }
  p { margin: 0; }
  ul { margin: 0; padding-left: 1.15rem; display: flex; flex-direction: column; gap: .5rem; }
  li::marker { color: var(--accent); }
  .lede { color: var(--muted); font-size: .9rem; }
  .scroll { overflow-x: auto; border: 1px solid var(--line); border-radius: 2px; background: var(--card); }
  table { border-collapse: collapse; width: 100%; min-width: 34rem; font-size: .9rem; }
  caption { caption-side: bottom; padding: .6rem .9rem; color: var(--muted); font-size: .8rem; text-align: left; }
  th, td { padding: .6rem .9rem; text-align: left; vertical-align: top; border-bottom: 1px solid var(--line); }
  tbody tr:last-child th, tbody tr:last-child td { border-bottom: 0; }
  thead th { font-size: .72rem; font-weight: 700; letter-spacing: .06em; color: var(--muted); white-space: nowrap; }
  td.num, th.num { text-align: right; font-variant-numeric: tabular-nums; white-space: nowrap; }
  .term th { width: 8.5rem; font-weight: 700; white-space: nowrap; }
  code { font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, monospace; font-size: .84em; background: var(--accent-bg); color: var(--ink); padding: .1rem .35rem; border-radius: 2px; }
  .pill { display: inline-flex; align-items: center; gap: .35rem; font-size: .78rem; font-weight: 700; white-space: nowrap; }
  .pill::before { content: ""; width: 7px; height: 7px; border-radius: 50%; background: currentColor; }
  .pill.high { color: var(--sev-high); }
  .pill.mid { color: var(--sev-mid); }
  .pill.low { color: var(--sev-low); }
  footer { border-top: 1px solid var(--line); padding-top: 1.1rem; color: var(--muted); font-size: .82rem; line-height: 1.7; display: flex; flex-direction: column; gap: .3rem; }
</style>
</head>
<body>
<article class="doc">

  <header class="head">
    <h1>{기능명} 작업 회고</h1>
    <div class="rule" aria-hidden="true">
      <i></i><i class="on"></i><i></i><i class="on"></i><i></i><i></i><i class="on"></i><i></i><i class="on"></i><i></i><i class="on"></i><i></i><i></i><i class="on"></i><i></i><i class="on"></i><i></i><i class="on"></i><i></i><i></i>
    </div>
    <p class="meta">
      <span>{YYYY-MM-DD} ~ {YYYY-MM-DD}</span>
      <span>브랜치 <code>{브랜치명}</code></span>
      <span>작성자 {git config user.name}</span>
    </p>
  </header>

  <dl class="summary">
    <div><dt>한 줄 요약</dt><dd>{무엇을 했는지 한 문장. 기술 용어 없이}</dd></div>
    <div><dt>왜 했나</dt><dd>{이 작업이 없었으면 어떤 문제가 계속됐는지}</dd></div>
    <div><dt>무엇이 달라졌나</dt><dd>{사용자나 팀 입장에서 체감되는 변화}</dd></div>
  </dl>

  <section>
    <h2>이 회고가 본 것</h2>
    <p class="lede">아래 근거만 확인하고 썼습니다. 여기에 없는 것은 이 문서가 다루지 않습니다.</p>
    <div class="scroll">
      <table>
        <thead><tr><th>근거</th><th>범위</th></tr></thead>
        <tbody>
          <tr><td>커밋</td><td>{N개 — 전부/일부, 기준 브랜치 {BASE} 대비}</td></tr>
          <tr><td>기획·리뷰 문서</td><td>{plan M건, review K건}</td></tr>
          <tr><td>세션 대화</td><td>{P개, YYYY-MM-DD ~ YYYY-MM-DD — 또는 보지 않은 사유}</td></tr>
          <tr><td>다루지 않은 범위</td><td>{기준 브랜치 이전 이력, 다른 브랜치의 관련 작업 등}</td></tr>
        </tbody>
      </table>
    </div>
  </section>

  <section>
    <h2>용어 풀이</h2>
    <p class="lede">이 문서에 나오는 개발 용어를 먼저 풀어 둡니다.</p>
    <div class="scroll"><table class="term"><tbody>
      <tr><th scope="row">{용어}</th><td>{일상어 한 줄 설명}</td></tr>
    </tbody></table></div>
  </section>

  <section>
    <h2>문제를 어떻게 알게 됐나</h2>
    <p class="lede">기능을 만들기로 결정하기까지, 무엇을 보고 무엇을 확인했는지의 기록입니다.</p>
    <div class="scroll">
      <table>
        <thead><tr><th>시점</th><th>관측한 것</th><th>여기서 알게 된 것</th><th>근거</th></tr></thead>
        <tbody><tr><td>{날짜}</td><td>{눈에 띈 신호 — 문의, 오류, 지표, 직접 관찰}</td><td>{그 관측이 좁혀준 범위}</td><td class="src">{커밋 해시 · 대화 날짜 · 문서 경로 — 추정이면 (추정)}</td></tr></tbody>
      </table>
      <caption>{개별 대응이 아니라 이 작업을 하기로 판단한 이유 한 줄}</caption>
    </div>
  </section>

  <section>
    <h2>기획 방향</h2>
    <ul>
      <li><strong>해결하려던 문제</strong> — {문제와 그 크기. 가능하면 숫자로}</li>
      <li><strong>초기 설계 방향</strong> — {docs/plan 기반}</li>
      <li><strong>이번에 하지 않기로 한 것</strong> — {범위 밖으로 둔 것과 그 이유}</li>
    </ul>
  </section>

  <section>
    <h2>주요 구현 내용</h2>
    <ul><li>{핵심 변경사항 3~5개}</li></ul>
  </section>

  <section>
    <h2>정리 먼저 — 고치기 전에 치운 것</h2>
    <p class="lede">동작을 바꾸는 변경과, 동작은 그대로 두고 구조만 정리하는 변경을 섞지 않았습니다. 정리를 먼저 따로 커밋해 두면 나중에 문제가 생겼을 때 어느 쪽이 원인인지 바로 가려낼 수 있습니다.</p>
    <div class="scroll">
      <table>
        <thead><tr><th>정리한 것</th><th>왜 먼저 했나</th><th>동작 변화</th><th>커밋</th></tr></thead>
        <tbody>
          <tr><td>{이름 변경 · 추출 · 중복 제거 · 위치 이동}</td><td>{이 정리가 없었으면 다음 작업이 왜 어려웠는지}</td><td><span class="pill low">없음</span></td><td><code>{해시}</code></td></tr>
          <tr><td>— 여기서부터 실제 기능 —</td><td>{정리 위에 무엇을 얹었는지}</td><td><span class="pill mid">있음</span></td><td><code>{해시}</code></td></tr>
        </tbody>
      </table>
      <caption>{정리와 기능을 나눈 덕에 실제로 도움이 된 지점. 없었으면 이 섹션째로 삭제}</caption>
    </div>
  </section>

  <section>
    <h2>작업 단계별 기록</h2>
    <div class="scroll">
      <table>
        <thead><tr><th class="num">단계</th><th>내용</th><th>커밋</th><th class="num">소요</th></tr></thead>
        <tbody><tr><td class="num">{N}</td><td>{내용}</td><td><code>{해시}</code></td><td class="num">{기간}</td></tr></tbody>
      </table>
      <caption>{단계를 그렇게 나눈 이유 한 줄}</caption>
    </div>
  </section>

  <section>
    <h2>의사결정 기록</h2>
    <p class="lede">작업 중 갈림길에서 무엇을 고르고 무엇을 버렸는지, 그리고 나중에 되돌릴 수 있는 결정인지 남깁니다.</p>
    <div class="scroll">
      <table>
        <thead><tr><th>갈림길</th><th>고른 길</th><th>버린 길과 이유</th><th>되돌리기</th><th>근거</th></tr></thead>
        <tbody><tr><td>{무엇을 정해야 했는지}</td><td>{고른 것}</td><td>{버린 선택지와 버린 이유}</td><td><span class="pill low">쉬움</span></td><td class="src">{커밋 해시 · 대화 날짜 · 문서 경로 — 추정이면 (추정)}</td></tr></tbody>
      </table>
      <caption>{되돌리기 어려운 결정이 있으면 그것을 짚는 한 줄}</caption>
    </div>
  </section>

  <section>
    <h2>피드백 이력</h2>
    <div class="scroll">
      <table>
        <thead><tr><th>회차</th><th>날짜</th><th class="num">필수</th><th class="num">권장</th><th class="num">선택</th><th class="num">적용</th></tr></thead>
        <tbody><tr>
          <td>{N}차</td><td>{날짜}</td>
          <td class="num"><span class="pill high">{N}건</span></td>
          <td class="num"><span class="pill mid">{N}건</span></td>
          <td class="num"><span class="pill low">{N}건</span></td>
          <td class="num">{N}/{총}건</td>
        </tr></tbody>
      </table>
      <caption>{어떤 지적이 있었고 어떻게 해소됐는지 한 줄}</caption>
    </div>
  </section>

  <section>
    <h2>코드 변경 상세</h2>
    <p class="lede">개발자를 위한 항목입니다. 앞의 내용만으로 충분하다면 건너뛰셔도 됩니다.</p>
    <div class="scroll"><table>
      <thead><tr><th>파일</th><th>변경 전</th><th>변경 후</th><th>변경 이유</th></tr></thead>
      <tbody><tr><td><code>{경로}</code></td><td>{before 요약}</td><td>{after 요약}</td><td>{피드백 항목 or 설계 결정}</td></tr></tbody>
    </table></div>
  </section>

  <section>
    <h2>배운 점</h2>
    <ul><li>{새로 알게 된 것 · 다음에 참고할 패턴}</li></ul>
  </section>

  <section>
    <h2>개선 여지</h2>
    <ul><li>{현재 구현의 한계 · 향후 개선 가능한 부분}</li></ul>
  </section>

  <footer>
    <p>이 문서는 <code>/my-retro</code>로 생성되었습니다.</p>
  </footer>

</article>
</body>
</html>
```

내용이 없는 섹션은 자리표시자를 남기지 말고 해당 `<h2>` 블록째로 삭제합니다.

## 3단계: 재발 신호만 memory로 승격

회고 본문을 memory에 복사하지 않습니다. `docs/retro/`는 이번 작업의 서사이고, memory는 **다음 세션이 쓸 사실**입니다. 같은 내용을 양쪽에 두면 어느 쪽이 최신인지 알 수 없게 됩니다.

### 승격 조건

아래 중 하나에 해당하는 것만 옮깁니다. 하나도 없으면 **아무것도 쓰지 않습니다.** 빈손으로 끝나는 것이 정상입니다.

- 이번 작업에서 **두 번 이상** 걸린 함정
- 다음 작업에도 그대로 유효한 제약 — 환경 설정, 배포 절차, 외부 시스템의 성질
- 코드나 git 이력을 봐도 알 수 없는 결정의 배경

제외: 이번 브랜치에서 끝난 일회성 사건, 코드·커밋 메시지·CLAUDE.md에 이미 적혀 있는 것.

### 쓰기 전에 기존 memory를 먼저 읽습니다

```bash
ls ~/.claude/projects/<원본 프로젝트 mangled>/memory/
```

같은 주제의 파일이 이미 있으면 **새로 만들지 말고 그 파일을 갱신합니다.** 중복 파일이 쌓이면 다음 세션이 어느 쪽을 믿을지 알 수 없게 됩니다.

### 형식

기존 memory 파일의 규약을 그대로 따릅니다.

```markdown
---
name: <kebab-case-slug>
description: <한 줄 요약 — 다음 세션이 이 줄만 보고 열지 말지 판단합니다>
metadata:
  type: feedback | project | reference
---

<사실 한 개>

**Why:** <이 사실이 왜 성립하는가>
**How to apply:** <다음에 무엇을 다르게 할 것인가>
```

- 상대 날짜("지난주", "며칠 전")를 쓰지 않습니다. 절대 날짜로 적습니다.
- 관련 memory는 `[[다른-memory-이름]]`으로 연결합니다.
- 파일을 만들었으면 `MEMORY.md`에 `- [제목](파일.md) — 한 줄` 을 추가합니다. **인덱스에 없는 memory는 다음 세션에서 읽히지 않습니다.**

모든 산출물 경로를 반환합니다 — 회고 파일, 통합본, 아카이브 개수, 승격한 memory 파일. 커버리지(무엇을 보고 무엇을 못 봤는지)도 함께 반환합니다.

---

## 완료 보고 (메인 루프)

에이전트 완료 후 사용자에게 알립니다:

1. 생성된 회고 파일 경로 — HTML이면 브라우저로 바로 열 수 있음을 함께 안내합니다. 워크트리에서 실행했다면 "워크트리가 아니라 원본 체크아웃 `<경로>`에 저장했습니다"를 반드시 적습니다.
2. 커버리지 한 줄 — 커밋 N개, plan M건, review K건, 세션 대화 P개(또는 미조회 사유)
3. 통합된 plan/review 파일 경로 (통합이 발생한 경우만)
4. `_archive/`로 옮긴 원본 파일 개수 — "삭제가 아니라 이동이므로 되돌릴 수 있습니다"
5. memory에 승격한 항목 — 파일 경로와 한 줄 요약. **승격이 없었으면 "재발 신호가 없어 memory에는 쓰지 않았습니다"라고 명시합니다.** 조용히 넘어가면 사용자는 승격이 실패한 것인지 없었던 것인지 알 수 없습니다.
