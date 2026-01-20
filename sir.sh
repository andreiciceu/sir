#!/usr/bin/env bash
# SIR - Stateful Incremental Reasoner (AI-powered project assistant)
# Single-file, macOS-compatible (bash). Focused on clarity and minimalism.

set -euo pipefail

########################################
# CONFIG - override via env per project
########################################
SIR_DIR="${SIR_DIR:-.sir}"                      # directory for SIR state files
MEM="${MEM:-$SIR_DIR/memory}"                   # memory folder (stores PRD, tasks, etc.)

PRD="${PRD:-$MEM/PRD.md}"                       # Product Requirements Document (markdown)
TASKS="${TASKS:-$MEM/tasks.json}"               # Task list (JSON feature list)
PROG="${PROG:-$MEM/progress.txt}"               # Progress log (plain text)
GUIDE="${GUIDE:-$MEM/GUIDELINES.md}"            # Project guidelines documentation
INBOX="${INBOX:-$MEM/inbox}"                    # New inputs (notes, chats, meetings, etc)
PROCESSED="${PROCESSED:-$MEM/processed.txt}"    # processed file list/markers
STORIES="${STORIES:-$MEM/stories.md}"           # user stories (draft)

AI_CMD="${AI_CMD:-claude}"                      # AI command-line tool (e.g. Claude CLI)
AI_ARGS_DEFAULT=(${AI_ARGS_DEFAULT:-"-p"})      # default args for AI tool (prompt flag etc.)
CAN_ASK_CLARIFY="${CAN_ASK_CLARIFY:-true}"      # whether AI can ask clarifying questions

TONE="${TONE:-ultra-terse. drop fluff. ok bad grammar. no essays.}"

########################################
# UTILITIES
########################################
die(){ echo "err: $*" >&2; exit 1; }
ok(){ echo "$*"; }
need(){ command -v "$1" >/dev/null 2>&1 || die "need $1"; }
ts(){ date "+%Y-%m-%d %H:%M:%S"; }

# Invoke AI tool with given prompt (using default args plus any extra passed)
ai(){ "$AI_CMD" "${AI_ARGS_DEFAULT[@]}" "$@"; }

ensure_files(){
  mkdir -p "$MEM" "$INBOX"
  [[ -f "$PRD" ]] || : >"$PRD"
  [[ -f "$PROG" ]] || : >"$PROG"
  [[ -f "$GUIDE" ]] || : >"$GUIDE"
  [[ -f "$STORIES" ]] || : >"$STORIES"
  [[ -f "$PROCESSED" ]] || : >"$PROCESSED"  
  [[ -f "$TASKS" ]] || echo '{"tasks":[]}' >"$TASKS"  
}

# Assemble context for AI prompt (file paths and rules)
ctx(){
  cat <<EOF
SIR Context
-----------
Files:
- PRD: $PRD
- Tasks: $TASKS
- Progress: $PROG
- Guidelines: $GUIDE

Rules:
- $TONE
- CAN_ASK_CLARIFY: $CAN_ASK_CLARIFY
- Always be concise and clear; sacrifice grammar for the sake of concision.
- Use and update the files above directly (read/modify them as needed).
- **Do NOT remove or rewrite requirements/tests**; only mark tasks as done (passes=true) after proper completion.
- Follow any project-specific instructions in Guidelines (e.g., how to run tests or style conventions).
- Make minimal necessary changes for each task.
- If something is unclear, ask clarifying questions.
- If an error or block is encountered, output "<error>".
EOF
}

########################################
# COMMANDS
########################################

# 0. Initiator: Initialize SIR in the current project (creates .sir structure)
cmd_init(){
  ensure_files
  ok "SIR initialized in $SIR_DIR"
}

# 1. PRD Creator: Create PRD and initial task list from prompt or directory content
cmd_prd(){
  ensure_files
  local prompt="" scan_dir=""
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --prompt) prompt="${2:-}"; shift 2 ;;
      --dir)    scan_dir="${2:-}"; shift 2 ;;
      *) die "unknown arg: $1";;
    esac
  done
  [[ -n "$prompt" || -n "$scan_dir" ]] || die "usage: sir prd --prompt \"...\" | --dir <path>"
  [[ -z "$scan_dir" || -d "$scan_dir" ]] || die "dir not found: $scan_dir"

  # Call AI to generate PRD and tasks
  ai <<EOF
$(ctx)

Task: Create PRD (Product Requirements Document) and Task List.

Input:
- User prompt: ${prompt:-none}
- Scan directory: ${scan_dir:-none}

Steps:
1. Gather and understand the project goals from the input (prompt or scanned files).
2. If a scan_dir is provided, analyze its contents (code, notes) for relevant info.
3. Ask the user any clarifying questions needed until requirements are clear.
4. Write a **concise PRD** to "$PRD" (markdown format) describing the product objectives and features.
5. Create a list of small, independent tasks (features) from the PRD. Use JSON format:
   {
     "tasks": [
       {"id":"T001","title":"...","desc":"...","steps":["..."],"passes": false},
       ...
     ]
   }
   - Each task: a short title, a brief description, acceptance steps, passes=false.
   - All tasks should start as passes=false (not completed).
6. Save the tasks list to "$TASKS".
7. Append to "$PROG": $(ts) "PRD and tasks created."
8. Output "<success>prd created</success>" when done.
EOF
}

# 2. Rafael Wagyu: Implement tasks iteratively (one task per iteration)
cmd_rafael(){
  ensure_files
  local iterations=10
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --loop) iterations="${2:-1}"; shift 2 ;;
      *) die "unknown arg: $1";;
    esac
  done
  [[ "$iterations" =~ ^[0-9]+$ ]] || die "loop count must be a number"

  for ((i=1; i<=iterations; i++)); do
    local out
    out="$(ai <<EOF
$(ctx)

Task: Rafael Wagyu - Implement Next Task.

Steps:
1. Read "$PRD", "$TASKS", "$PROG", and "$GUIDE" to understand the project state and guidelines.
2. Identify the highest-priority task from "$TASKS" that has "passes": false (not done yet).
  This should be the one YOU decide has the highest priority - not necessarily the first in the list.
3. Plan the implementation for that task. If unclear, ask for clarification ONLY if CAN_ASK_CLARIFY is true.
4. Implement the task:
   - Make necessary code/file changes for the feature.
   - Use minimal changes to achieve the tasks acceptance criteria.
   - Adhere to coding guidelines from "$GUIDE".
5. Run any tests or feedback loops specified in "$GUIDE" (e.g., unit tests, linters) to verify the feature.
   - If issues are found, fix them before proceeding.
6. Once the feature is confirmed working, update the task in "$TASKS" by setting "passes": true.
7. Append to "$PROG": $(ts) "Implemented <Task ID>: <short description about progress and implementation>".
8. Create a git commit for this feature (use a descriptive commit message).
9. If *all* tasks are now passes=true, output "<promise>COMPLETE</promise>".
EOF
)"
    # Print AI output to terminal
    echo "$out"
    # Check for completion signal
    if [[ "$out" == *"<promise>COMPLETE</promise>"* ]]; then
      ok "All tasks completed. Exiting Rafael loop."
      break
    fi
  done
}

# 3. Guidar: Generate project Guidelines documentation
cmd_guidar(){
  ensure_files
  local scan_dir=""
  # Optional directory to scan for deriving guidelines
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dir) scan_dir="${2:-}"; shift 2 ;;
      *) die "unknown arg: $1";;
    esac
  done
  [[ -z "$scan_dir" || -d "$scan_dir" ]] || die "dir not found: $scan_dir"

  ai <<EOF
$(ctx)

Task: Guidar - Create/Update Project Guidelines.

Input:
- Scan directory: ${scan_dir:-none}

Steps:
1. If a project directory is provided, review its structure and key files (e.g., README, code files) to glean conventions or important info.
2. Ask the user for any additional project-specific guidelines (if something is unclear or missing).
3. Compile a **GUIDELINES.md** document (save to "$GUIDE") that covers:
   - Coding style conventions or best practices for this project.
   - Architectural decisions or design patterns to follow.
   - Any tools or commands to use for testing, building, etc.
   - Any other project-specific rules (from existing docs or user input).
4. Do not include irrelevant info; keep it short and project-focused.
5. Append to "$PROG": $(ts) "Guidelines created/updated."
6. Output "<success>guidelines created</success>" when done.
EOF
}

# 4. Storyteller: Create user stories for each task
cmd_storyteller(){
  ensure_files
  ai <<EOF
$(ctx)

Task: Storyteller - Generate User Stories.

Steps:
1. Read "$PRD" for overall context and "$TASKS" for the list of features.
2. For each task in "$TASKS" (each feature), write a concise **User Story** in the format:
   - As a <type of user>, I want <feature> so that <benefit>.
   - Include 2-3 acceptance criteria for each story (bullet points).
3. Use the PRD to ensure each story captures the intended functionality and value.
4. Save all user stories to a file (e.g., "$STORIES") in Markdown format.
   - Format as a list of user stories, clearly labeled or bullet-pointed.
5. Append to "$PROG": $(ts) "User stories created."
6. Output "<success>stories created</success>" when done.
EOF
}

# 5. Projector: Process new info and update project artifacts (PRD, tasks, etc.)
cmd_projector(){
  ensure_files
  local update_src=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dir)  update_src="${2:-}"; shift 2 ;;  # directory containing new info files
      --file) update_src="${2:-}"; shift 2 ;;  # single file of new info
      *) die "unknown arg: $1";;
    esac
  done
  [[ -z "$update_src" || -e "$update_src" ]] || die "source not found: $update_src"

  ai <<EOF
$(ctx)

Task: Projector - Integrate New Information into Project.

Input:
- processed markers file: $PROCESSED
- inbox dir: $INBOX

Steps:
- Determine unprocessed files by checking $PROCESSED.
- Summarize the key points or decisions from them.
- Identify any changes in requirements or new features mentioned in the new info.
- For each change/new requirement:
   - Update the "$PRD" if it changes the product scope or adds details.
   - If a new feature/task is identified, append it to "$TASKS" (with a new ID and passes=false).
   - If an existing task is affected (e.g., changed acceptance criteria), update its description or steps.
- Ensure not to duplicate tasks; maintain consistency in "$TASKS".
- If "$GUIDE" (guidelines) needs updates (e.g., new conventions or decisions), update it as well.
- Append to "$PROG": $(ts) "Project updated with new info: <brief summary>."
- Append processed filenames to $PROCESSED (one per line).
- (Optional) Prepare updates for JIRA or external trackers as needed, but do not execute them automatically.
- Output "<success>project updated</success>" when done.
EOF
}

########################################
# MAIN ENTRY POINT
########################################

usage(){
  cat <<EOF
SIR - Stateful Incremental Reasoner (CLI for AI project management)

Usage:
  sir init                       Initialize SIR in current project (create $SIR_DIR/ structure).
  sir prd --prompt "DESC"        Create PRD from a prompt (initial idea/requirements).
  sir prd --dir PATH             Create PRD by analyzing files in PATH (existing docs/code).
  sir rafael [--loop N]          Run Rafael (AI coder) N iterations (default 1). Use --loop 0 for infinite until complete.
  sir guidar [--dir PATH]        Generate GUIDELINES.md by scanning project files.
  sir storyteller                Produce user_stories.md from PRD and tasks.
  sir projector [--file F|--dir D] Process new info (file or dir) and update PRD/tasks.

Environment variables (override defaults per project):
  SIR_DIR, MEM, PRD, TASKS, PROG, GUIDE (file paths)
  AI_CMD, AI_ARGS_DEFAULT (AI backend command and default args)
  TONE (tone/style instructions for AI outputs)

Examples:
  ./sir.sh init
  ./sir.sh guidar --dir src/        # gather coding guidelines from src directory
  ./sir.sh prd --prompt "Build a Todo app"
  ./sir.sh rafael --loop 5         # implement tasks with up to 5 iterations
  ./sir.sh storyteller
  ./sir.sh projector --file meeting_notes.txt
EOF
}

main(){
  need "$AI_CMD"  # ensure AI command is available

  local cmd="${1:-}"; shift || true
  case "$cmd" in
    init)        cmd_init "$@" ;;
    prd)         cmd_prd "$@" ;;
    rafael)      cmd_rafael "$@" ;;
    guidar)      cmd_guidar "$@" ;;
    storyteller) cmd_storyteller "$@" ;;
    projector)   cmd_projector "$@" ;;
    ""|-h|--help|help) usage ;;
    *) die "unknown command: $cmd" ;;
  esac
}

main "$@"
