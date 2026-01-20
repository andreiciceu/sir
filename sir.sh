#!/usr/bin/env bash
# SIR — Stateful Incremental Reasoner
# Simple AI-powered tool for project management & development
# macOS + bash only. One file. Minimal.

set -euo pipefail

########################################
# CONFIG — override via env per project
########################################
SIR_DIR="${SIR_DIR:-.sir}"           # where SIR stores its state
MEM="${MEM:-$SIR_DIR/memory}"        # memory folder

PRD="${PRD:-$MEM/PRD.md}"            # product requirements
TASKS="${TASKS:-$MEM/tasks.json}"    # task list
PROG="${PROG:-$MEM/progress.txt}"    # activity log
GUIDE="${GUIDE:-$MEM/GUIDELINES.md}" # project guidelines

AI_CMD="${AI_CMD:-claude}"           # AI command to use
AI_ARGS_DEFAULT=(${AI_ARGS_DEFAULT:-"-p"})

TONE="${TONE:-ultra-terse. drop fluff. ok bad grammar. no essays.}"

########################################
# UTILITIES
########################################
die(){ echo "err: $*" >&2; exit 1; }
ok(){ echo "$*"; }
need(){ command -v "$1" >/dev/null 2>&1 || die "need $1"; }
ts(){ date "+%Y-%m-%d %H:%M:%S"; }

ai(){ "$AI_CMD" "${AI_ARGS_DEFAULT[@]}" "$@"; }

ensure_files(){
  mkdir -p "$MEM"
  [[ -f "$PRD" ]]   || : >"$PRD"
  [[ -f "$PROG" ]]  || : >"$PROG"
  [[ -f "$TASKS" ]] || echo '{"tasks":[]}' >"$TASKS"
  [[ -f "$GUIDE" ]] || : >"$GUIDE"
}

ctx(){
  # Context for AI: file locations + rules
  cat <<EOF
SIR Context
-----------
Files to use:
- PRD: $PRD
- Tasks: $TASKS  
- Progress: $PROG
- Guidelines: $GUIDE

Rules:
- $TONE
- In all interactions and outputs, be extremly concise and sacrifice grammar for the sake of concision.
- Read/edit files directly. Create if missing.
- Minimal changes only.
- If blocked: output <error>.
- Avoid comments and explanations unless explicitly needed.
- Value clarity, simplicity, minimalism
EOF
}

########################################
# COMMANDS
########################################

cmd_init(){
  ensure_files
  ok "SIR initialized in $SIR_DIR"
}

# Create PRD from prompt or directory scan
cmd_prd(){
  ensure_files
  local prompt="" scan_dir=""
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --prompt) prompt="${2:-}"; shift 2;;
      --dir) scan_dir="${2:-}"; shift 2;;
      *) die "unknown arg: $1";;
    esac
  done
  
  [[ -n "$prompt" || -n "$scan_dir" ]] || die "need --prompt or --dir"
  [[ -z "$scan_dir" || -d "$scan_dir" ]] || die "dir not found: $scan_dir"

  ai <<EOF
$(ctx)

Task: Create PRD (Product requirements document) + Tasks

Input:
- User prompt: ${prompt:-none}
- Scan directory: ${scan_dir:-none}

Steps:
1. Read input. If scan_dir provided, analyze files in it.
2. Ask clarification questions until everything is clear.
3. Write PRD to $PRD in markdown format.
4. Write tasks to $TASKS with schema:
   {"tasks":[{"id":"T001","title":"...","desc":"...","steps":["..."],"passes":false}]}
   Keep tasks small & independent. All passes=false initially.
5. Log to $PROG: timestamp + "prd+tasks created"

Output: "<success>prd created</success>"
EOF
}

# Rafael Wagyu: implement tasks one by one
cmd_rafael(){
  local iterations=10  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --loop) iterations="${2:-1}"; shift 2;;
      *) die "unknown arg: $1";;
    esac
  done
  
  [[ "$iterations" =~ ^[0-9]+$ ]] || die "loop must be number"  
  
  for ((i=1; i<=$iterations; i++)); do    
    local out
    out="$(ai <<EOF
$(ctx)

Task: Rafael Wagyu — Implement One Task

Steps:
1. Read $PRD, $TASKS, $PROG, $GUIDE
2. Decide which task to work on next
    This should be the one YOU decide has the highest priority - not necessarily the first in the list.
3. Check any feedback loops, such as types and tests.
4. Append your progress to the $PROG file.
5. Make a git commit of that feature. ONLY WORK ON A SINGLE FEATURE. 
    If, while implementing the feature, you notice that all work is complete, output <promise>COMPLETE</promise>.
6. Update $TASKS: set passes=true ONLY if all steps done.

EOF
)"
    
    echo "$out"    
    if [[ "$out" == *"<promise>COMPLETE</promise>"* ]]; then
        echo "PRD complete, exiting."
        exit 0
    fi
  done
}

########################################
# MAIN
########################################

usage(){
  cat <<EOF
SIR — Stateful Incremental Reasoner

Usage:
  sir init                     # initialize .sir folder
  sir prd --prompt "..."       # create PRD from prompt
  sir prd --dir path           # create PRD from directory scan
  sir rafael [--loop N]        # run Rafael (default 1 iteration)

Environment variables:
  SIR_DIR, MEM, PRD, TASKS, PROG, GUIDE
  AI_CMD, AI_ARGS_DEFAULT, TONE

Examples:
  ./sir.sh init
  ./sir.sh prd --prompt "build a todo app"
  ./sir.sh rafael --loop 5
EOF
}

main(){
  need "$AI_CMD"
  
  local cmd="${1:-}"; shift || true
  
  case "$cmd" in
    init)    cmd_init "$@";;
    prd)     cmd_prd "$@";;
    rafael)  cmd_rafael "$@";;
    ""|-h|--help|help) usage;;
    *) die "unknown command: $cmd";;
  esac
}

main "$@"
