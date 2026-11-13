#!/usr/bin/env bash
# 글로벌(user 스코프) MCP 서버 등록 — 재현 가능한 단일 소스.
#
#   bash mcp-install.sh                  Claude·Codex 양쪽에 등록
#   bash mcp-install.sh --target codex   Codex에만 등록
#
# 재실행 안전: 이미 등록된 서버는 건너뛴다.
# sequential-thinking·serena는 2026-11 제외 — 최신 모델의 내장 추론·코드 탐색과 겹쳐 토큰만 늘린다.
# 버전은 의도적으로 고정(pin)한다. 업데이트는 아래 PIN 값을 bump + commit 후 재실행.
set -euo pipefail

# ---- pinned versions (검증된 버전) ----
CONTEXT7_VER="3.2.5"
SHRIMP_VER="1.0.21"

# shrimp 태스크 데이터는 외장 볼륨에 둔다. Claude·Codex가 같은 DATA_DIR을
# 공유해야 태스크 목록이 갈라지지 않는다.
SHRIMP_DATA_DIR="${SHRIMP_DATA_DIR:-/Volumes/860QVO/.shrimp-data}"

TARGET_ARG="all"
while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET_ARG="${2:-}"; shift 2 ;;
    --target=*) TARGET_ARG="${1#*=}"; shift ;;
    -h|--help)
      echo "사용법: bash mcp-install.sh [--target claude|codex|all]"
      exit 0 ;;
    *) echo "알 수 없는 인자: $1" >&2; exit 1 ;;
  esac
done

case "$TARGET_ARG" in
  all) TARGETS="claude codex" ;;
  claude|codex) TARGETS="$TARGET_ARG" ;;
  *) echo "  ✗ 알 수 없는 타깃: '$TARGET_ARG' (claude|codex|all)" >&2; exit 1 ;;
esac

# DATA_DIR의 부모가 없으면 볼륨이 마운트되지 않은 것이다. 여기서 mkdir 해버리면
# 태스크 데이터가 두 곳으로 갈라지므로, 만들지 말고 중단한다.
DATA_PARENT="$(dirname "$SHRIMP_DATA_DIR")"
if [ ! -d "$DATA_PARENT" ]; then
  echo "  ✗ DATA_DIR 부모 경로 없음: $DATA_PARENT" >&2
  echo "    외장 볼륨이 마운트되지 않았을 수 있습니다." >&2
  echo "    다른 위치를 쓰려면: SHRIMP_DATA_DIR=/경로 bash mcp-install.sh" >&2
  exit 1
fi
mkdir -p "$SHRIMP_DATA_DIR" && chmod 700 "$SHRIMP_DATA_DIR"

mcp_get() {
  case "$1" in
    claude) claude mcp get "$2" ;;
    codex)  codex  mcp get "$2" ;;
  esac
}

# add <target> <name> [K=V ...] -- <command> [args...]
# 이미 등록돼 있으면 건너뛴다. 갱신하려면 먼저 remove 한 뒤 재실행한다.
add() {
  local t="$1" name="$2"; shift 2
  local envs=()
  while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do envs+=("$1"); shift; done
  shift   # "--" 소비

  if mcp_get "$t" "$name" >/dev/null 2>&1; then
    echo "  ↺ $name ($t) — 갱신하려면 remove 후 재실행"
    return 0
  fi

  local flags=() e
  # bash 3.2에서는 set -u와 빈 배열 확장이 충돌하므로 ${arr[@]+...} 관용구를 쓴다.
  for e in ${envs[@]+"${envs[@]}"}; do
    case "$t" in
      claude) flags+=(-e "$e") ;;
      codex)  flags+=(--env "$e") ;;
    esac
  done

  case "$t" in
    claude) claude mcp add -s user "$name" ${flags[@]+"${flags[@]}"} -- "$@" ;;
    codex)  codex  mcp add         "$name" ${flags[@]+"${flags[@]}"} -- "$@" ;;
  esac
  echo "  ✓ $name ($t)"
}

register_all() {
  local t="$1"
  add "$t" context7            -- npx -y "@upstash/context7-mcp@${CONTEXT7_VER}"
  add "$t" shrimp-task-manager "DATA_DIR=${SHRIMP_DATA_DIR}" -- npx -y "mcp-shrimp-task-manager@${SHRIMP_VER}"
}

for t in $TARGETS; do
  if ! command -v "$t" >/dev/null 2>&1; then
    echo "  ⚠ $t CLI 없음 — 건너뜀"
    continue
  fi
  echo "  [$t] MCP 서버 등록 (DATA_DIR=$SHRIMP_DATA_DIR)"
  register_all "$t"
done

echo ""
echo "등록 확인:"
for t in $TARGETS; do
  command -v "$t" >/dev/null 2>&1 || continue
  echo "--- $t ---"
  case "$t" in
    claude) claude mcp list ;;
    codex)  codex  mcp list ;;
  esac
done
