#!/bin/bash
# OpenAI Codex 알림음 훅 설치 스크립트
#
#   bash settings/install-codex-hooks.sh              설치 (재실행해도 중복되지 않음)
#   bash settings/install-codex-hooks.sh --uninstall  제거
#
# ~/.codex/hooks.json 을 통째로 덮지 않고 `hooks`에만 병합합니다.
# 이 파일에는 사용자의 다른 훅(예: rtk PreToolUse)이 들어 있습니다.
#
# 이 스크립트가 넣은 훅은 command 끝의 `# my-cc-config:sound` 마커로 식별하며,
# 재실행 시 마커가 붙은 훅만 걷어내고 다시 넣으므로 다른 훅은 건드리지 않습니다.
#
# Codex의 훅 이벤트에는 Notification·StopFailure가 없으므로 Stop만 설치합니다.
# (Codex 0.152.0 지원 이벤트: PreToolUse, PermissionRequest, PostToolUse,
#  PreCompact, PostCompact, SessionStart, SessionEnd, UserPromptSubmit,
#  SubagentStart, SubagentStop, Stop, Interrupt)
#
# Claude 조각과 달리 async 필드를 넣지 않습니다. Codex는 모르는 필드가 있으면
# 그 훅을 조용히 버립니다 — 에러도, 신뢰 프롬프트도 뜨지 않아 원인을 찾기
# 어렵습니다. codex exec에 --dangerously-bypass-hook-trust를 주고 실행했을 때
# async가 있으면 훅이 돌지 않고, 빼면 `hook: Stop`이 찍히는 것으로 확인했습니다.
#
# 설치했다고 바로 도는 것도 아닙니다. Codex는 훅을 `파일:이벤트:그룹:인덱스` 단위로
# 해시 신뢰하며, config.toml의 [hooks.state]에 등록되기 전까지는 조용히 건너뜁니다.
# 등록은 settings/trust-codex-hooks.sh가 합니다(install.sh가 마지막에 호출).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FRAGMENT="$REPO_DIR/settings/codex-notification-sounds.json"
SETTINGS="${CODEX_HOOKS:-$HOME/.codex/hooks.json}"
MARK="# my-cc-config:sound"

command -v jq >/dev/null 2>&1 || { echo "  ✗ jq가 필요합니다 — brew install jq"; exit 1; }
[ -f "$FRAGMENT" ] || { echo "  ✗ 훅 정의 파일 없음: $FRAGMENT"; exit 1; }

mkdir -p "$(dirname "$SETTINGS")"
[ -f "$SETTINGS" ] || echo '{}' >"$SETTINGS"

if ! jq empty "$SETTINGS" >/dev/null 2>&1; then
  echo "  ✗ $SETTINGS 가 올바른 JSON이 아닙니다. 먼저 고친 뒤 다시 실행하세요."
  exit 1
fi

BACKUP="$SETTINGS.bak-$(date +%Y%m%d-%H%M%S)"
cp "$SETTINGS" "$BACKUP"

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

# 마커가 붙은 훅을 걷어내고, 그 결과 비어버린 항목은 통째로 제거한다.
STRIP='
  def stripMarked($mark):
    ((. // [])
     | map(.hooks |= map(select(((.command // "") | contains($mark)) | not)))
     | map(select((.hooks | length) > 0)));
'

if [ "${1:-}" = "--uninstall" ]; then
  jq --arg mark "$MARK" "$STRIP"'
    .hooks //= {}
    | .hooks |= with_entries(.value |= stripMarked($mark))
    | .hooks |= with_entries(select((.value | length) > 0))
  ' "$SETTINGS" >"$TMP"
  ACTION="제거"
else
  # 같은 matcher를 쓰는 항목이 이미 있으면 그 안에 훅만 덧붙이고, 없으면 새 항목을 만든다.
  jq --arg mark "$MARK" --slurpfile frag "$FRAGMENT" "$STRIP"'
    def mergeEntry($entry):
      . as $arr
      | ([$arr | to_entries[] | select(.value.matcher == $entry.matcher) | .key]) as $idx
      | if ($idx | length) > 0
        then (.[$idx[0]].hooks += $entry.hooks)
        else . + [$entry]
        end;
    .hooks //= {}
    | reduce ($frag[0] | to_entries[]) as $e (.;
        .hooks[$e.key] = (
          reduce $e.value[] as $entry
            ((.hooks[$e.key] | stripMarked($mark)); mergeEntry($entry))))
  ' "$SETTINGS" >"$TMP"
  ACTION="설치"
fi

if ! jq empty "$TMP" >/dev/null 2>&1; then
  echo "  ✗ 병합 결과가 올바른 JSON이 아닙니다. 원본을 그대로 두었습니다: $SETTINGS"
  exit 1
fi

mv "$TMP" "$SETTINGS"
trap - EXIT

echo "  ✓ Codex 알림음 훅 $ACTION 완료 — $SETTINGS"
echo "    백업: $BACKUP"
echo "    Codex는 hooks.json을 해시로 신뢰합니다. 단독 실행했다면: bash settings/trust-codex-hooks.sh"
