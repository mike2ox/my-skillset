---
name: my-memo
description: 팀원과 나눈 기술/프로젝트 대화를 기반으로 웹 리서치 후 Obsidian 인사이트 메모를 생성하고 Vault의 _inbox 폴더에 직접 저장합니다. 승격은 사용자가 수동으로 합니다.
disable-model-invocation: true
argument-hint: [--output <파일-경로>] [--vault <경로>] [대화 내용 또는 주제]
allowed-tools: Agent Bash(cat *) Bash(ls *) Bash(mkdir *) Bash(date *) Write(*) AskUserQuestion
---

팀원과 나눈 대화 내용을 바탕으로 웹 리서치를 통해 Obsidian 인사이트 메모를 생성하고, Vault에 **파일로 직접 저장**합니다.

## 설계 원칙 (반드시 지킬 것)

- **저장·사용자 질문은 메인 루프가 담당한다.** 서브에이전트는 리서치와 초안 작성만 한다.
  - 이유: `AskUserQuestion`은 서브에이전트에서 동작하지 않고, `Write`도 메인 루프에만 부여된다.
- **저장은 자동, 승격은 수동.** `--output`이 없으면 메모는 `10_Notes/_inbox/`에 자동 저장한다. `10_Notes/` 본체로의 승격은 사용자가 나중에 수동으로 한다. (자동 저장으로 세션 휘발을 막고, `_inbox` 격리로 Vault 오염을 막는다.)
- **리서치 전에 저장 경로부터 확인한다.** 비싼 리서치를 한 뒤 저장할 곳이 없어 버리는 일을 방지.

## 경로 설정

Vault 루트는 **하드코딩하지 않고** `vault.conf`(이 SKILL.md와 같은 디렉터리)에서 읽는다. Vault가 이동하면 `vault.conf`의 `VAULT_ROOT` 한 줄만 고치면 되고, SKILL.md 본문은 건드릴 필요가 없다.

- 설정 파일: `vault.conf` (같은 스킬 폴더 내), 형식: `VAULT_ROOT=<절대경로>`
- 이번 실행에서만 다른 Vault를 쓰고 싶으면 `$ARGUMENTS` 맨 앞 옵션에 `--vault <경로>`를 붙인다. 예: `/my-memo --vault /Volumes/다른디스크/OtherVault 이 내용 정리해줘`
  - `--vault`가 주어지면 이번 실행에서는 그 값을 최우선으로 쓰고, `vault.conf`는 변경하지 않는다(임시 override).
- 메모 저장 폴더(inbox): `{VAULT_ROOT}/10_Notes/_inbox/`
- 일지 폴더: `{VAULT_ROOT}/00_Index/`
- 파일명 규칙: `{YYYY-MM-DD} {핵심키워드}.md` (제목에 `/` 등 경로 특수문자 금지)

### 출력 파일 override

- `$ARGUMENTS` 맨 앞 옵션에 `--output <파일-경로>`를 붙이면 그 정확한 파일 경로가 저장 대상이 된다. `--vault`와 함께 쓸 수 있으며, 두 옵션은 어느 순서로 와도 된다. 공백이 있는 경로는 인용한다.
- `--output`은 **파일 경로**만 받는다. 상대 경로는 현재 프로젝트 디렉터리 기준으로 해석하며, 디렉터리만 넘기면 올바른 파일 경로를 AskUserQuestion으로 다시 받는다.
- `--output`이 있으면 Vault inbox 경로보다 우선한다. `vault.conf`는 바꾸지 않고, inbox 폴더의 존재 확인·생성도 하지 않는다.
- 지정한 파일의 상위 디렉터리가 없으면 임의로 만들지 말고, 생성 / 다른 경로 지정 / 저장 취소 중 하나를 AskUserQuestion으로 묻는다. 지정한 파일이 이미 있으면 자동으로 덮어쓰지 말고, 덮어쓰기 / 다른 파일 경로 / 저장 취소 중 하나를 AskUserQuestion으로 묻는다.
- `--output`이 없을 때의 Vault 확인, inbox 저장 위치, 파일명 규칙, 중복 처리 흐름은 아래 기존 규칙을 그대로 적용한다.

---

## 0단계: 사전조건 체크 (메인 루프, Bash)

리서치를 시작하기 **전에** `--output`을 우선 해석하고 저장 경로를 확인한다. `--output`이 없을 때만 Vault 경로를 확정한다.

`--output`이 없을 때에만 아래 명령을 실행한다. `$ARGUMENTS`에 `--vault <경로>`가 있으면 그 값을, 없으면 `vault.conf`의 `VAULT_ROOT`를 쓴다.

```bash
cat ~/.claude/skills/my-memo/vault.conf
```

- `--output`이 있으면 지정 파일의 상위 디렉터리 존재와 쓰기 가능 여부를 확인한다. 없거나 쓸 수 없으면 위 출력 파일 override의 AskUserQuestion 흐름을 따르고, Vault inbox 확인은 건너뛴다.
- `--output`이 없고 `--vault` override가 없으면 위에서 읽은 `VAULT_ROOT` 값을 이후 모든 단계에서 그대로 사용한다.
- `--output`이 없을 때에만 그 다음 저장 경로 존재를 확인한다:

```bash
ls -d "{VAULT_ROOT}/10_Notes/_inbox/" 2>/dev/null || mkdir -p "{VAULT_ROOT}/10_Notes/_inbox/"
```

- 외장 SSD가 언마운트되어 `{VAULT_ROOT}` 자체가 없으면, mkdir이 실패한다(예: `/Volumes/...`에 상위 마운트 포인트가 없어 엉뚱한 빈 폴더가 새로 생성되는 사고를 막기 위해, mkdir 전에 `{VAULT_ROOT}`의 **상위 디렉터리**가 실제로 존재하는지 먼저 확인한다).
  이때는 AskUserQuestion으로 사용자에게 알리고 선택지를 제시한다:
  - a) 외장 SSD 마운트 후 재시도
  - b) `--vault`로 다른 경로 지정
  - c) 이번엔 화면 출력만 하고 저장 생략
  경로가 확보되지 않으면 리서치(1~2단계)로 진행하지 않는다.
- 오늘 날짜 확인: `date +%Y-%m-%d`

## 1단계: 주제 파악 (메인 루프)

`$ARGUMENTS`에서 선행 `--output <파일-경로>`와 `--vault <경로>` 토큰이 있으면 0단계에서 이미 처리했으므로 모두 제거하고, 나머지를 대화 내용으로 취급한다.

대화 내용에서 추출한다:
- 핵심 기술 주제 (1-3개)
- 등장한 기술 용어/키워드
- 논의된 문제 또는 컨텍스트

이를 바탕으로 파일명 후보를 정한다. 형식: `{YYYY-MM-DD} {핵심키워드}.md`

## 2단계: 리서치 위임 (메인 루프 → Agent)

Agent 도구로 서브에이전트를 띄운다. 서브에이전트에게 다음을 지시한다.

- **역할**: 웹 리서치 + 메모 초안 작성. **파일을 쓰지 말고, 사용자에게 질문하지 말 것.**
- **허용 도구**: WebSearch, WebFetch (Write/AskUserQuestion 금지 — 애초에 동작 안 함)
- **리서치**: 핵심 주제 관련 최소 3회 WebSearch. 소스별로 URL/제목/핵심요약 기록.
  - 공식 문서 / StackOverflow 주요 Q&A / 저명 개발자 아티클 / GitHub·RFC·이슈 / 트렌드 아티클
- **반환 형식(고정)**: 아래 섹션으로만 응답하게 한다.
  ```
  SUGGESTED_TITLE: <파일명에 쓸 제목 후보 1~2개>
  BODY: <메모 "심화 내용" 마크다운 초안>
  SOURCES: <제목 | URL | 유형 표에 들어갈 목록>
  OPEN_QUESTIONS: <심화 방향 후보 2~4개. 예: A) 원리 deep-dive / B) 실무 패턴 / C) 비교 분석 / D) 트렌드>
  ```

## 3단계: 방향 선택 (메인 루프, AskUserQuestion)

서브에이전트가 반환한 `OPEN_QUESTIONS`(심화 방향 후보)를 AskUserQuestion으로 사용자에게 묻는다.
- 질문 예: "이 주제를 어떤 방향으로 정리할까요?" / options: 파악한 2-4가지 방향
- 이 답을 반영해 최종 심화 내용을 확정하고, 파일명(제목)도 확정한다.
- (참고: 서브에이전트 안에서는 이 질문이 불가능하므로 반드시 메인 루프에서 한다.)

## 4단계: 메모 조립 및 저장 (메인 루프, Write)

아래 형식으로 메모 전체를 조립한다.

```md
---
tags: [memo, inbox, {기술카테고리}, {세부키워드1}, {세부키워드2}]
date: {YYYY-MM-DD}
status: inbox
source: my-memo
journal: "[[{YYYY-MM-DD}]]"
---

# {주제 제목}

## 대화 내용

{$ARGUMENTS 원문 전체를 그대로 기재 — 단, 1단계에서 제거한 `--output <파일-경로>`·`--vault <경로>` 토큰은 제외}

## 심화 내용

{선택한 방향을 기반으로 리서치한 내용 — 소제목을 활용해 구조화}

## 출처

| 제목 | 링크 | 유형 |
|------|------|------|
| {제목} | {URL} | 공식문서 / 아티클 / StackOverflow / GitHub |

## 인사이트 키워드

- **{키워드}**: {이 개념에서 얻을 수 있는 인사이트 한 줄}
- **{키워드}**: {인사이트}
```

frontmatter 필드 의미:
- `status: inbox` / `tags`에 `inbox` — 아직 승격 전 초안임을 표시. Obsidian 그래프뷰·검색에서 `-#inbox`로 걸러낼 수 있다.
- `source: my-memo` — 이 스킬이 자동 생성한 메모임을 식별(나중에 일괄 검색/정리용).
- `journal: "[[{YYYY-MM-DD}]]"` — 오늘 일지로의 **frontmatter backlink**. 일지 파일을 직접 수정하지 않아도 Obsidian이 일지의 backlink 패널에 이 메모를 표시한다.

**저장 실행:**
- 저장 직전 경로 존재를 한 번 더 가볍게 확인한다(그 사이 언마운트 대비).
- 대상: `--output`이 있으면 0단계에서 확정한 그 파일 경로, 없으면 `{VAULT_ROOT}/10_Notes/_inbox/{YYYY-MM-DD} {제목}.md` (`{VAULT_ROOT}`는 0단계에서 확정한 값)
- **중복 파일명 처리**: `--output`이 없을 때 동일 기본 경로가 이미 있으면 자동으로 덮어쓰지 말 것. AskUserQuestion으로
  "덮어쓰기 / 다른 이름(`(2)` 등) / 취소"를 사용자에게 물어 결정한다. (append 금지 — 서로 다른 리서치를 한 파일에 섞지 않는다.)

## 5단계: 결과 보고 및 실패 폴백

- **저장 성공** → 사용자에게 저장된 **절대경로**와 간단한 내용 요약을 보고한다.
  - `--output`이 없을 때만 승격 안내: "이 메모는 `_inbox`에 초안으로 저장되었습니다. 검토 후 좋으면 `10_Notes/` 본체로 옮겨 승격하세요."
- **저장 실패**(경로 부재·권한 등) → "메모를 생성했습니다"라고만 말하지 말 것.
  조립한 메모 **전체를 코드블록으로 출력**하고, 실패 사유 + 수동 저장 안내로 강등한다.
  (리서치 결과 텍스트는 메인 루프 컨텍스트에 이미 있으므로 유실되지 않는다.)

---

## 일지 연결 방법 (사용자 안내용)

이 스킬은 메모 frontmatter에 `journal: "[[{YYYY-MM-DD}]]"`를 넣어 **자동으로 일지와 backlink 연결**한다.
- 오늘 일지(`{VAULT_ROOT}/00_Index/{YYYY-MM-DD}.md`)를 열면 Obsidian의 **Backlinks 패널**에 이 메모가 나타난다.
- 일지 본문에 눈에 보이는 링크를 원하면, 승격 시점에 일지의 `## Reference` 섹션에 아래를 직접 추가한다:
  ```
  [[{파일명 확장자 제외}]]
  ```
