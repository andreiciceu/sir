#!/usr/bin/env bash
# SIR — Stateful Incremental Reasoner or Supreme Intelligence for Reasoning
# Simple AI-powered tool for project management & development
# one bash file. macOS. ultra-minimal. prompt harness + state.
# agent-agnostic: swap AI_CMD + AI_ARGS + prompt parts in CONFIG.

set -euo pipefail

########################################
# CONFIG (project override via env)
########################################
SIR_DIR="${SIR_DIR:-.sir}"
MEM="${MEM:-$SIR_DIR/memory}"

PRD="${PRD:-$MEM/PRD.md}"
TASKS="${TASKS:-$MEM/tasks.json}"
PROG="${PROG:-$MEM/progress.txt}"
GUIDE="${GUIDE:-$MEM/GUIDELINES.md}"

INBOX="${INBOX:-$MEM/inbox}"              # new inputs (notes, chats, meetings, etc)
PROCESSED="${PROCESSED:-$MEM/processed.txt}" # processed file list/markers
STORIES="${STORIES:-$MEM/stories.md}"     # user stories (draft)
LOCK="${LOCK:-$SIR_DIR/.lock}"            # coarse lock

# Agent cmd + args. keep generic.
AI_CMD="${AI_CMD:-claude}"
# Common pattern: tool reads stdin prompt, outputs to stdout.
# Override per agent: e.g. AI_ARGS_DEFAULT='-p' or 'run' etc.
AI_ARGS_DEFAULT_STR="${AI_ARGS_DEFAULT_STR:-"-p"}"

# Tone + meta rules (ultra-terse)
TONE="${TONE:-ultra-terse. no fluff. short lines. ok bad grammar.}"

# Prompt parts (swap these if agent changes)
P_SYS="${P_SYS:-You are SIR. do exact tasks. be terse.}"
P_FORMAT="${P_FORMAT:-Output only needed. If need user input: emit <ask>Q</ask> then stop.}"
P_GUARD="${P_GUARD:-Never hallucinate file contents. Read files. Edit files directly. Minimal diffs.}"

# Git behavior
GIT="${GIT:-git}"
AUTO_COMMIT="${AUTO_COMMIT:-0}"   # 1 = attempt commit; 0 = just tell user commands

########################################
# UTIL
########################################
die(){ echo "err: $*" >&2; exit 1; }
ok(){ echo "$*"; }
need(){ command -v "$1" >/dev/null 2>&1 || die "need $1"; }
ts(){ date "+%Y-%m-%d %H:%M:%S"; }

ai(){
  # stdin prompt in, stdout out
  # shellcheck disable=SC2086
  "$AI_CMD" $AI_ARGS_DEFAULT_STR
}

ensure_files(){
  mkdir -p "$MEM" "$INBOX"
  [[ -f "$PRD" ]] || : >"$PRD"
  [[ -f "$PROG" ]] || : >"$PROG"
  [[ -f "$GUIDE" ]] || : >"$GUIDE"
  [[ -f "$STORIES" ]] || : >"$STORIES"
  [[ -f "$PROCESSED" ]] || : >"$PROCESSED"
  [[ -f "$TASKS" ]] || echo '{"tasks":[]}' >"$TASKS"
}

# list files in a dir, small + safe.
scan_dir(){
  local d="$1"
  [[ -d "$d" ]] || die "dir not found: $d"
  # keep small. ignore huge binaries.
  (cd "$d" && find . -type f \
    ! -path "*/.git/*" ! -path "*/node_modules/*" ! -path "*/.sir/*" \
    -maxdepth 5 -print | sed 's|^\./||')
}

ctx(){
  cat <<EOF
$P_SYS

SIR Context
Files:
- PRD: $PRD
- Tasks: $TASKS
- Progress: $PROG
- Guidelines: $GUIDE
- Stories: $STORIES
- Inbox: $INBOX
- Processed markers: $PROCESSED

Rules:
- $TONE
- $P_GUARD
- $P_FORMAT

Ops:
- Prefer append-only logs ($PROG).
- Keep tasks tiny + independent (one commit sized).
- When blocked: emit <ask>...</ask> only.
- When done: emit <done/> only.
EOF
}

########################################
# PROMPT HELPERS (best practices)
########################################
# Pattern: "plan small, do 1 step, update state, stop"
# Avoid multi-step long runs. prefer one iteration loops.
preamble(){
  cat <<EOF
$(ctx)

Hard constraints:
- One step only per run unless explicitly told loop.
- If changing code: run fastest checks available (format/lint/tests) but keep minimal.
- Update $TASKS + $PROG on every run (even if no changes).
- Never mark task passes=true unless verified (tests/build or clear manual check).
EOF
}

########################################
# COMMANDS
########################################

cmd_init(){
  ensure_files
  ok "ok: init $SIR_DIR"
}

cmd_guidar(){
  ensure_files
  local scan_dir_path="${1:-.}"
  [[ -d "$scan_dir_path" ]] || die "dir not found: $scan_dir_path"

  local files
  files="$(scan_dir "$scan_dir_path" | head -n 200)"

  ai <<EOF
$(preamble)

Tool: Guidar
Goal: create/refresh project guidelines.

Input:
- repo dir: $scan_dir_path
- file list (partial): 
$files

Do:
1) infer stack, conventions, folder map, commands (build/test/lint), style rules.
2) ask if any critical missing info.
3) write concise $GUIDE (max ~200 lines). bullets. examples tiny.
4) append $PROG: "$(ts) guidar updated"

Output: <done/> OR <ask>..</ask>
EOF
}

cmd_prd(){
  ensure_files
  local prompt="" scan_dir_path=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --prompt) prompt="${2:-}"; shift 2;;
      --dir) scan_dir_path="${2:-}"; shift 2;;
      *) die "unknown arg: $1";;
    esac
  done
  [[ -n "$prompt" || -n "$scan_dir_path" ]] || die "need --prompt or --dir"
  [[ -z "$scan_dir_path" || -d "$scan_dir_path" ]] || die "dir not found: $scan_dir_path"

  local files=""
  if [[ -n "$scan_dir_path" ]]; then
    files="$(scan_dir "$scan_dir_path" | head -n 250)"
  fi

  ai <<EOF
$(preamble)

Tool: PRD Creator
Goal: produce PRD + small tasks.

Input:
- user prompt: ${prompt:-none}
- scan dir: ${scan_dir_path:-none}
- scan file list (partial):
${files:-none}

Loop rule:
- If anything unclear: output ONLY <ask>Q1; Q2; ...</ask> and stop.
- Do NOT write PRD/tasks until clarified enough.

When clear:
1) write $PRD (markdown). sections: Goal, Users, Scope, Non-goals, UX notes, Data/API, Acceptance, Risks.
2) write $TASKS as JSON:
{"tasks":[{"id":"T001","title":"...","desc":"...","steps":["..."],"deps":["T000"],"status":"todo","passes":false}]}
- status: todo|doing|blocked|done
- keep tasks 0.5-2h. independent. strict acceptance in steps.
3) append $PROG: "$(ts) prd+tasks updated"

Output: <done/> OR <ask>..</ask>
EOF
}

cmd_storyteller(){
  ensure_files
  ai <<EOF
$(preamble)

Tool: Storyteller
Goal: create user stories from PRD+tasks.

Do:
1) read $PRD and $TASKS
2) write $STORIES as markdown list grouped by task id.
Format each:
- ID, Title
- As a..., I want..., so that...
- Acceptance (bullets)
- Notes (optional)
3) append $PROG: "$(ts) stories updated"
4) stop. no jira calls. user will paste.

Output: <done/> OR <ask>..</ask>
EOF
}

cmd_projector(){
  ensure_files
  # process new info in INBOX not in PROCESSED
  local new_files
  new_files="$( (cd "$INBOX" && find . -type f -maxdepth 5 -print | sed 's|^\./||') | sort )"

  ai <<EOF
$(preamble)

Tool: Projector
Goal: sync PRD/tasks/stories from new info.

Input:
- inbox dir: $INBOX
- processed markers file: $PROCESSED
- new files list:
$new_files

Rules:
- Determine unprocessed files by checking $PROCESSED.
- For each unprocessed file, read it, summarize in 1-5 bullets, then:
  - update PRD if scope/req changed
  - update TASKS (add/split/reword). keep ids stable if possible.
  - update STORIES if needed.
- Append $PROG with timestamp + summary of what changed.
- Append processed filenames to $PROCESSED (one per line).
- If conflict/unclear: <ask>...</ask> only.

Output: <done/> OR <ask>..</ask>
EOF
}

cmd_rafael(){
  ensure_files
  local iterations=1
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --loop) iterations="${2:-1}"; shift 2;;
      *) die "unknown arg: $1";;
    esac
  done
  [[ "$iterations" =~ ^[0-9]+$ ]] || die "loop must be number"

  for ((i=1; i<=iterations; i++)); do
    local out
    out="$(ai <<EOF
$(preamble)

Tool: Rafael Wagyu
Goal: implement ONE task. tiny. safe.

Do (strict):
1) Read $GUIDE, $PRD, $TASKS, $PROG.
2) Pick ONE task with status=todo (or blocked->now unblocked). set it status=doing.
3) Implement only that task. minimal diffs.
4) Verify: run smallest relevant check (build/test/lint). If none known, say what you'd run.
5) Update $TASKS:
   - if verified: status=done, passes=true
   - else: status=blocked or todo, passes=false, add note in desc
6) Append $PROG:
   "$(ts) T###: what done. checks: X. next: Y."
7) Git:
   - if AUTO_COMMIT=1 and repo clean enough: commit message "T###: title"
   - else: output shell cmds to run commit (no essay).

Stop:
- If all tasks done: output <done/> only.
- If blocked on user decision: output <ask>...</ask> only.

Output: <done/> OR <ask>..</ask>
EOF
)"
    echo "$out"
    [[ "$out" == *"<ask>"* ]] && exit 0
  done
}

cmd_initiator(){  
  ensure_files
    
  local readme="$SIR_DIR/README.txt"
  [[ -f "$readme" ]] || cat >"$readme" <<EOF
SIR state folder.
- memory/PRD.md
- memory/tasks.json
- memory/GUIDELINES.md
- memory/stories.md
- memory/progress.txt
- memory/inbox/ (drop new notes here)
EOF
  ok "ok: initiator done"
}

########################################
# MAIN
########################################
usage(){
  cat <<EOF
SIR

Usage:
  sir init
  sir initiator
  sir guidar [repo_dir]
  sir prd --prompt "..." | --dir path
  sir storyteller
  sir projector
  sir rafael [--loop N]

Env:
  SIR_DIR MEM PRD TASKS PROG GUIDE INBOX PROCESSED STORIES
  AI_CMD AI_ARGS_DEFAULT_STR
  TONE P_SYS P_FORMAT P_GUARD
  AUTO_COMMIT=0|1

Examples:
  ./sir.sh initiator
  ./sir.sh guidar .
  ./sir.sh prd --prompt "feature: ..."
  ./sir.sh storyteller
  ./sir.sh rafael --loop 3
  ./sir.sh projector
EOF
}

main(){
  need "$AI_CMD"
  need python3 || true
  local cmd="${1:-}"; shift || true
  
  case "$cmd" in
    init)        cmd_init "$@";;
    initiator)   cmd_initiator "$@";;
    guidar)      cmd_guidar "$@";;
    prd)         cmd_prd "$@";;
    storyteller) cmd_storyteller "$@";;
    projector)   cmd_projector "$@";;
    rafael)      cmd_rafael "$@";;
    ""|-h|--help|help) usage;;
    *) die "unknown cmd: $cmd";;
  esac
}

main "$@"
