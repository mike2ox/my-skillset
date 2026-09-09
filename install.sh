#!/bin/bash
# my-skillset 설치 스크립트 — Claude Code / OpenAI Codex 양쪽 타깃 지원
#
#   bash install.sh                      양쪽 타깃 전부 설치
#   bash install.sh --target codex       Codex만 설치
#   bash install.sh --prune              저장소에 없는 고아 심링크까지 정리
#
# 재실행해도 안전하다(멱등). 이미 올바르게 걸린 링크는 건드리지 않고,
# 깨졌거나 옛 경로를 가리키는 링크만 다시 연결한다.

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_ARG="all"
PRUNE=0

usage() {
  cat <<'USAGE'
사용법: bash install.sh [옵션]

옵션:
  --target <claude|codex|all>  설치 대상 (기본: all)
  --prune                      저장소에 더 이상 없는 고아 심링크를 삭제
  -h, --help                   이 도움말

타깃별 설치 범위:
  claude  ~/.claude/skills · ~/.claude/agents · MCP 4종 · 알림음 훅 3종(Stop/Notification/StopFailure)
  codex   ~/.codex/skills  · MCP 4종 · 알림음 훅 1종(Stop)

  Codex에는 Notification·StopFailure 훅 이벤트가 없어 Stop만 설치된다.
  서브에이전트는 Claude Code 전용이라 Codex에는 설치되지 않는다.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET_ARG="${2:-}"; shift 2 ;;
    --target=*) TARGET_ARG="${1#*=}"; shift ;;
    --prune) PRUNE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "알 수 없는 인자: $1" >&2; usage >&2; exit 1 ;;
  esac
done

# ---------------------------------------------------------------- 타깃 추상화

resolve_targets() {
  case "$1" in
    all) echo "claude codex" ;;
    claude|codex) echo "$1" ;;
    *) echo "  ✗ 알 수 없는 타깃: '$1' (claude|codex|all)" >&2; return 1 ;;
  esac
}

target_home() {
  case "$1" in
    claude) echo "$HOME/.claude" ;;
    codex)  echo "$HOME/.codex" ;;
  esac
}

# 경로는 env로 덮어쓸 수 있다(비표준 설치 위치, 테스트 용도).
target_skills_dir() {
  case "$1" in
    claude) echo "${CLAUDE_SKILLS_DIR:-$(target_home claude)/skills}" ;;
    codex)  echo "${CODEX_SKILLS_DIR:-$(target_home codex)/skills}" ;;
  esac
}

# 서브에이전트는 Claude Code 전용 기능이다. Codex에는 대응 개념이 없으므로
# 빈 문자열을 돌려주고, 호출부가 이를 보고 건너뛴다.
target_agents_dir() {
  case "$1" in
    claude) echo "${CLAUDE_AGENTS_DIR:-$(target_home claude)/agents}" ;;
    codex)  echo "" ;;
  esac
}

# 스킬 링크는 홈 디렉토리만 있으면 걸 수 있고, MCP 등록은 CLI가 필요하다.
target_installed() { [ -d "$(target_home "$1")" ] || [ -d "$(target_skills_dir "$1")" ]; }
target_cli()       { command -v "$1" >/dev/null 2>&1; }

TARGETS="$(resolve_targets "$TARGET_ARG")" || exit 1

# ------------------------------------------------------------------- 심링크

# 링크가 가리키는 경로를 그대로 읽는다. macOS 기본 readlink에는 -f가 없으므로
# 링크를 해석하지 않고 문자열만 비교한다(깨진 링크도 대상을 읽을 수 있다).
link_target_of() {
  local link="$1" raw
  raw="$(readlink "$link" 2>/dev/null)" || return 1
  echo "${raw%/}"
}

link_skills() {
  local target="$1" dir
  dir="$(target_skills_dir "$target")"
  mkdir -p "$dir"

  local skill_dir name src link current
  for skill_dir in "$REPO_DIR/skills"/*/; do
    name="$(basename "$skill_dir")"
    src="${skill_dir%/}"
    link="$dir/$name"

    if [ -L "$link" ]; then
      current="$(link_target_of "$link")"
      if [ "$current" = "$src" ] && [ -e "$link" ]; then
        echo "    ↺ $name"
      else
        rm -f "$link"
        ln -s "$src" "$link"
        echo "    ⟳ $name (재연결: ${current:-?} → $src)"
      fi
    elif [ -d "$link" ]; then
      echo "    ⚠ $name (실제 디렉토리 — 교체하려면 수동 제거 필요)"
    else
      ln -s "$src" "$link"
      echo "    ✓ $name"
    fi
  done
}

# 에이전트는 디렉토리가 아니라 .md 파일 하나가 단위다. 그래서 link_skills와
# 합치지 않고 따로 둔다 — 존재 검사(-d vs -f)와 순회 대상이 다르다.
link_agents() {
  local target="$1" dir
  dir="$(target_agents_dir "$target")"
  [ -n "$dir" ] || return 0
  [ -d "$REPO_DIR/agents" ] || return 0
  mkdir -p "$dir"

  local f name src link current
  for f in "$REPO_DIR/agents"/*.md; do
    [ -e "$f" ] || continue
    name="$(basename "$f")"
    src="$f"
    link="$dir/$name"

    if [ -L "$link" ]; then
      current="$(link_target_of "$link")"
      if [ "$current" = "$src" ] && [ -e "$link" ]; then
        echo "    ↺ $name"
      else
        rm -f "$link"
        ln -s "$src" "$link"
        echo "    ⟳ $name (재연결: ${current:-?} → $src)"
      fi
    elif [ -e "$link" ]; then
      echo "    ⚠ $name (실제 파일 — 교체하려면 수동 제거 필요)"
    else
      ln -s "$src" "$link"
      echo "    ✓ $name"
    fi
  done
}

# 이 저장소가 소유한 링크인지 판정한다. 현재 경로뿐 아니라 옛 저장소 이름도
# 인정해야 rename 이후 남은 링크를 정리할 수 있다. 다른 프로젝트가 건 링크는
# 여기서 걸러져 절대 삭제 대상이 되지 않는다.
OWNED_REPO_NAMES="my-skillset my-claude-code-config"

is_owned_link() {
  local current="$1" name="$2" kind="${3:-skills}" parent repo known
  case "$current" in
    */"$kind"/"$name") ;;
    *) return 1 ;;
  esac
  parent="${current%/$kind/$name}"
  [ "$parent/$kind/$name" = "$REPO_DIR/$kind/$name" ] && return 0
  repo="$(basename "$parent")"
  for known in $OWNED_REPO_NAMES; do
    [ "$repo" = "$known" ] && return 0
  done
  return 1
}

# 저장소에 대응 스킬이 없는데 남아 있는 링크를 고아로 본다.
# 실제 디렉토리(.system 등)와 다른 프로젝트를 가리키는 링크는 건드리지 않는다.
prune_orphans() {
  local target="$1" kind="${2:-skills}" dir link name current found=0
  case "$kind" in
    skills) dir="$(target_skills_dir "$target")" ;;
    agents) dir="$(target_agents_dir "$target")" ;;
  esac
  [ -n "$dir" ] && [ -d "$dir" ] || return 0

  for link in "$dir"/*; do
    [ -L "$link" ] || continue
    name="$(basename "$link")"
    current="$(link_target_of "$link")"
    is_owned_link "$current" "$name" "$kind" || continue
    [ -e "$REPO_DIR/$kind/$name" ] && continue

    found=1
    if [ "$PRUNE" = "1" ]; then
      rm -f "$link"
      echo "    ✗ $name 삭제됨 (was: $current)"
    else
      echo "    ! $name (고아 — was: $current)"
    fi
  done

  if [ "$found" = "1" ] && [ "$PRUNE" != "1" ]; then
    echo "    → 삭제하려면: bash install.sh --prune"
  fi
}

# --------------------------------------------------------------------- 실행

for t in $TARGETS; do
  echo ""
  echo "[$t]"

  if ! target_installed "$t"; then
    echo "  ⚠ $(target_home "$t") 없음 — 미설치로 보고 건너뜁니다."
    if [ "$TARGET_ARG" = "$t" ]; then exit 1; fi
    continue
  fi

  echo "  스킬 심링크 → $(target_skills_dir "$t")"
  link_skills "$t"
  prune_orphans "$t"

  agents_dir="$(target_agents_dir "$t")"
  if [ -n "$agents_dir" ]; then
    echo "  에이전트 심링크 → $agents_dir"
    link_agents "$t"
    prune_orphans "$t" agents
  else
    echo "  에이전트 심링크 — 건너뜀 ($t은 서브에이전트 미지원)"
  fi

  echo "  MCP 서버 등록"
  if target_cli "$t"; then
    bash "$REPO_DIR/mcp-install.sh" --target "$t" \
      || echo "    ⚠ 실패 — 수동 실행: bash mcp-install.sh --target $t"
  else
    echo "    ⚠ $t CLI 없음 — 건너뜀. 설치 후: bash mcp-install.sh --target $t"
  fi

  echo "  알림음 훅"
  case "$t" in
    claude) bash "$REPO_DIR/settings/install-sounds.sh" \
              || echo "    ⚠ 실패 — 수동 실행: bash settings/install-sounds.sh" ;;
    codex)  bash "$REPO_DIR/settings/install-codex-hooks.sh" \
              || echo "    ⚠ 실패 — 수동 실행: bash settings/install-codex-hooks.sh" ;;
  esac
done

echo ""
echo "완료. 적용하려면 해당 제품을 재시작하세요."
printf "커맨드: "
ls "$REPO_DIR/skills" | sed 's|^|/|' | tr '\n' ',' | sed 's/,$//; s/,/, /g'
echo ""
case "$TARGETS" in
  *codex*) echo "참고: Codex에는 Stop 알림음만 설치됩니다 (Notification·StopFailure 이벤트 미지원)." ;;
esac
