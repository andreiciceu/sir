#!/usr/bin/env bash
# SIR — Stateful Incremental Reasoner (Simple Intelligence for Reasoning)
# bash-only, macOS. minimal. agent edits files directly.

set -euo pipefail

########################################
# CONFIG (per project; override via env)
########################################
SIR_DIR="${SIR_DIR:-.sir}"
MEM="${MEM:-$SIR_DIR/memory}"

PRD="${PRD:-$MEM/PRD.md}"
TASKS="${TASKS:-$MEM/tasks.json}"
PROG="${PROG:-$MEM/progress.txt}"
GUIDE="${GUIDE:-$MEM/GUIDELINES.md}"
AGENTS="${AGENTS:-$MEM/AGENTS.md}"

AI_CMD="${AI_CMD:-claude}"
AI_ARGS_DEFAULT=(${AI_ARGS_DEFAULT:-"-p"})

TONE="${TONE:-ultra-terse. drop fluff. ok bad grammar. no essays.}"

########################################
# utils
########################################
die(){ echo "err: $*" >&2; exit 1; }
ok(){ echo "$*"; }
need(){ command -v "$1" >/dev/null 2>&1 || die "need $1"; }
ts(){ date "+%Y-%m-%d %H:%M:%S"; }

ai(){
  local prompt="$1"
  "$AI_CMD" "${AI_ARGS_DEFAULT[@]}" "$prompt"
}

ensure_files(){
  mkdir -p "$MEM"
  [[ -f "$PRD" ]]   || : >"$PRD"
  [[ -f "$PROG" ]]  || : >"$PROG"
  [[ -f "$TASKS" ]] || echo '{"tasks":[]}' >"$TASKS"
  [[ -f "$GUIDE" ]] || : >"$GUIDE"
  [[ -f "$AGENTS" ]] || cat >"$AGENTS" <<EOF
SIR agent rules
- $TONE
- use given paths as source of truth
- edit files directly; create if missing
- minimal changes
- if missing info: output ONLY Q: lines
- Rafael: 1 task/iter. pick first passes=false
- never set passes=true unless steps done; if skipped say so in notes
EOF
}

sir_header(){
  cat <<EOF
SIR ctx (paths)
ROOT: .
SIR: $SIR_DIR
MEM: $MEM
PRD: $PRD
TASKS: $TASKS
PROG: $PROG
GUIDE: $GUIDE
AGENTS: $AGENTS

Rules
- $TONE
- use files above as source of truth
- edit files directly. create if missing.
- keep changes minimal.
- if info missing: output ONLY Q: lines.
EOF
}


########################################
# commands
########################################

cmd_init(){
  ensure_files
  ok "init ok"
}

cmd_prd(){
  ensure_files
  local src_prompt="" src_dir=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --prompt) src_prompt="${2:-}"; shift 2;;
      --dir) src_dir="${2:-}"; shift 2;;
      *) die "bad arg";;
    esac
  done
  [[ -n "$src_prompt" || -n "$src_dir" ]] || die "need --prompt or --dir"
  [[ -z "$src_dir" || -d "$src_dir" ]] || die "no dir"

  local body
  body="$(cat <<EOF
Task: PRD Creator
Input:
- user_prompt: ${src_prompt:-"(none)"}
- scan_dir: ${src_dir:-"(none)"}

Do:
1) read Input. if scan_dir set, read files under it.
2) ask Q: until clear (ONLY Q: lines).
3) write PRD to: PRD
4) write TASKS to: TASKS
   schema: {"tasks":[{"id":"T001","title":"...","desc":"...","steps":["..."],"passes":false}]}
   keep tasks small+independent. all passes=false.
5) append 1 line to PROG: timestamp + "prd+tasks updated"
Output: either Q: lines OR 1-line "prd ok"
EOF
)"
  ai "$(sir_header)"$'\n\n'"$body"
}

cmd_rafael(){
  ensure_files
  local loop=1
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --loop) loop="${2:-1}"; shift 2;;
      *) die "bad arg";;
    esac
  done
  [[ "$loop" =~ ^[0-9]+$ ]] || die "bad loop"
  (( loop >= 1 && loop <= 50 )) || die "loop range 1..50"

  local i=0
  while (( i < loop )); do
    i=$((i+1))
    local body
    body="$(cat <<EOF
Task: Rafael Wagyu (1 iter)
Do:
1) read PRD, TASKS, PROG, GUIDE, AGENTS
2) pick first task with passes=false (if none: output "no tasks" and stop)
3) implement ONLY that task in repo (edit/create files as needed)
4) update TASKS: only that task id; passes=true only if steps done; else passes=false + notes
5) append to PROG: timestamp + 1-5 terse lines (what changed, why, next)
Output: ONLY one of:
- Q: lines (if blocked)
- 1-line status: "done T00X" OR "no tasks"
EOF
)"
    local out
    out="$(ai "$(sir_header)"$'\n\n'"$body")" || die "ai fail"
    echo "$out"
    echo "$out" | grep -q '^Q:' && exit 2
    echo "$out" | grep -q '^no tasks' && exit 0
  done
}

usage(){
  cat <<EOF
sir: init | prd --prompt "..." | prd --dir path | rafael [--loop N]
env override: SIR_DIR MEM PRD TASKS PROG GUIDE AGENTS AI_CMD AI_ARGS_DEFAULT TONE
EOF
}

main(){
  need "$AI_CMD"
  local cmd="${1:-}"; shift || true
  case "$cmd" in
    init) cmd_init "$@";;
    prd) cmd_prd "$@";;
    rafael) cmd_rafael "$@";;
    ""|-h|--help|help) usage;;
    *) die "bad cmd";;
  esac
}

main "$@"
