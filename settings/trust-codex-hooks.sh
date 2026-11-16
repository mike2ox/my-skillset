#!/bin/bash
# Codex 훅 신뢰 등록 스크립트
#
#   bash settings/trust-codex-hooks.sh
#
# Codex는 훅을 `파일:이벤트:그룹:인덱스` 키 단위로 해시 신뢰하며, 신뢰되지 않은 훅은
# 에러 없이 조용히 건너뜁니다. 대화형 세션에서 승인 창이 뜨기 전까지는 rtk 훅도
# 알림음 훅도 돌지 않으므로, 설치 직후 여기서 신뢰를 등록합니다.
#
# 해시를 직접 계산하지 않습니다. Codex app-server의 `hooks/list`가 돌려주는
# currentHash를 그대로 `config/value/write`로 [hooks.state]에 쓰게 해서, 해시 규칙이
# 바뀌어도 Codex가 계산한 값과 어긋나지 않게 합니다.
#
# 이 저장소가 설치한 훅만 신뢰합니다 — `rtk hook codex`와 `# my-cc-config:sound`
# 마커가 붙은 훅. 사용자가 따로 건 훅은 승인 여부를 사용자 판단에 맡깁니다.
#
# 신뢰는 키(위치)와 해시(내용)에 묶이므로 hooks.json이 바뀌면 다시 풀립니다.
# install.sh에서는 rtk·알림음 훅을 모두 건 뒤 마지막에 실행해야 합니다.
#
# 주의: cmux 안의 `codex`는 --dangerously-bypass-hook-trust를 붙여 실행되므로
# 거기서 훅이 돈다고 신뢰가 등록된 것은 아닙니다. 확인은 이 스크립트의 출력으로 하세요.
set -euo pipefail

command -v codex >/dev/null 2>&1 || { echo "  ✗ codex CLI가 필요합니다"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "  ✗ python3가 필요합니다 (app-server JSON-RPC 통신용)"; exit 1; }

python3 -I - <<'PY'
import json, os, select, subprocess, sys, time

MARK = "# my-cc-config:sound"
OWNED = lambda cmd: cmd == "rtk hook codex" or MARK in cmd

proc = subprocess.Popen(["codex", "app-server"], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                        stderr=subprocess.DEVNULL, text=True, bufsize=1)

def call(i, method, params, timeout=30):
    proc.stdin.write(json.dumps({"id": i, "method": method, "params": params}) + "\n")
    proc.stdin.flush()
    end = time.time() + timeout
    while time.time() < end:
        ready, _, _ = select.select([proc.stdout], [], [], 1)
        if not ready:
            continue
        line = proc.stdout.readline()
        if not line:
            break
        msg = json.loads(line)
        if msg.get("id") == i:
            if "error" in msg:
                raise RuntimeError(f"{method}: {msg['error']}")
            return msg["result"]
    raise RuntimeError(f"{method}: 응답 없음 (app-server 종료 또는 {timeout}s 초과)")

def owned_hooks():
    res = call(2, "hooks/list", {"cwds": [os.path.expanduser("~")]})
    return [h for entry in res["data"] for h in entry["hooks"]
            if h.get("source") == "user" and h.get("handlerType") == "command"
            and OWNED(h.get("command", ""))]

try:
    call(1, "initialize", {"clientInfo": {"name": "my-skillset", "title": None, "version": "1"},
                           "capabilities": None})
    proc.stdin.write(json.dumps({"method": "initialized"}) + "\n")
    proc.stdin.flush()

    hooks = owned_hooks()
    if not hooks:
        print("    ⚠ 신뢰할 훅 없음 — rtk·알림음 훅이 설치됐는지 확인하세요")
        sys.exit(0)

    pending = {h["key"]: {"trusted_hash": h["currentHash"]}
               for h in hooks if h["trustStatus"] != "trusted"}
    if pending:
        call(3, "config/value/write", {"keyPath": "hooks.state", "value": pending,
                                       "mergeStrategy": "upsert"})

    for h in owned_hooks():
        label = "rtk" if h["command"] == "rtk hook codex" else "알림음"
        mark = "✓" if h["trustStatus"] == "trusted" else "✗"
        state = "신뢰 등록" if h["key"] in pending else "이미 신뢰됨"
        if h["trustStatus"] != "trusted":
            state = f"등록 실패 ({h['trustStatus']})"
        print(f"    {mark} {h['eventName']} · {label} — {state}")
        if h["trustStatus"] != "trusted":
            sys.exit(1)
except RuntimeError as e:
    print(f"    ✗ codex app-server 통신 실패 — {e}")
    sys.exit(1)
finally:
    proc.terminate()
PY
