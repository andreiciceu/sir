#!/usr/bin/env bash
# SIR - Stateful Incremental Reasoner & (AI-powered project assistant)
# Supreme Intelligence for Reasoning
# Single-file, macOS-compatible (bash). Focused on clarity and minimalism.

set -euo pipefail

########################################
# CONFIG - override via env per project
########################################
SIR_DIR="${SIR_DIR:-.sir}"                      # directory for SIR state files
MEM="${MEM:-$SIR_DIR/memory}"                   # memory folder (stores PRD, tasks, etc.)

PRD="${PRD:-$MEM/PRD.md}"                       # Product Requirements Document (markdown)
STORIES="${STORIES:-$MEM/stories.md}"           # user stories (draft)
TASKS="${TASKS:-$MEM/tasks.json}"               # Task list (JSON feature list)
PROG="${PROG:-$MEM/progress.txt}"               # Progress log (plain text)
GUIDE="${GUIDE:-$MEM/GUIDELINES.md}"            # Project guidelines documentation
INBOX="${INBOX:-$MEM/inbox}"                    # New inputs (notes, chats, meetings, etc)
PROCESSED="${PROCESSED:-$MEM/processed.txt}"    # processed file list/markers

# AI_CMD="${AI_CMD:-"claude -p"}"               # AI command-line tool (e.g. Claude CLI)
AI_CMD="${AI_CMD:-"opencode run"}"              # AI command-line tool (e.g. Claude CLI)
AI_INTERACTIVE="${AI_INTERACTIVE:-"opencode --model github-copilot/claude-sonnet-4.5 --prompt"}"  # AI command-line tool for interactive mode
CAN_ASK_CLARIFY="${CAN_ASK_CLARIFY:-true}"      # whether AI can ask clarifying questions

TONE="${TONE:-ultra-terse. drop fluff. ok bad grammar. no essays.}"

########################################
# UTILITIES
########################################
die(){ echo "err: $*" >&2; exit 1; }
ok(){ echo "$*"; }
need(){ command -v "$1" >/dev/null 2>&1 || die "need $1"; }
ts(){ date "+%Y-%m-%d %H:%M:%S"; }

# Invoke AI tool with given prompt (passed as <EOF ... EOF> (which is stdin) or first arg)
ai(){
  local prompt=""
  if [[ $# -gt 0 ]]; then
    prompt="$1"
  else
    prompt="$(cat)"
  fi
  echo "===== AI PROMPT =====" >&2
  echo "$prompt" >&2
  echo "=====================" >&2
  
  local output
  if ! output=$(echo "$prompt" | $AI_CMD 2>&1); then
    echo "err: AI command failed" >&2
    return 1
  fi
  echo "$output"
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

ctx(){
  cat <<EOF
SIR - Stateful Incremental Reasoner & (AI-powered project assistant)
Context
-----------
Files:
- Guidelines: $GUIDE (project coding/design guidelines)
- PRD: $PRD (Product Requirements Document)
- Stories: $STORIES (user stories list)
- Tasks: $TASKS (JSON list of tasks/features)
- Progress: $PROG (always append a summary of changes, after each operation, with timestamp and short description )

Settings:
- Tone: $TONE
- CAN_ASK_CLARIFY (Can ask clarifying questions): $CAN_ASK_CLARIFY

Rules:
- Always be concise and clear; sacrifice grammar for the sake of concision.
- Use and update the files above directly (read/modify them as needed).
- Follow any project-specific instructions in Guidelines (e.g., how to run tests or style conventions).
- Make minimal necessary changes for each task.
- If an error or block is encountered, output "<error>".
EOF
}


########################################
# PROMPTS
########################################
prd_prompt(){
  cat <<EOF
# Task: Create PRD (Product Requirements Document) and Task List.

Steps:
- Gather and understand the project goals from the input (prompt or scanned files).
- Ask the user any clarifying questions needed until requirements are clear.
- Write a **concise PRD** to "$PRD" (markdown format) describing the product objectives and features.
- Create a list of small tasks in "$TASKS", independent tasks (features) from the PRD. Use JSON format:
   {
     "tasks": [
       {"id":"T001","title":"...","desc":"...","steps":["..."],"passes": false},
       ...
     ]
   }
   - Each task: a short title, a brief description, acceptance steps, passes=false.
   - All tasks should start as passes=false (not completed).
   - Use divide-and-conquer to break down features into small tasks, that can be implemented independently
   - Tasks must have low complexity, and estimated at most a 2 hours of work each.
- Append a progress summary to "$PROG"
- Output "<success>PRD created</success>" when done.
EOF
}

rafael_prompt(){
  cat <<EOF
# Task: Rafael Wagyu - Implement Next Task.

- **Do NOT remove or rewrite requirements/tests**; only mark tasks as done (passes=true) after proper completion.

Steps:
- Read "$PRD", "$TASKS", "$PROG", and "$GUIDE" to understand the project state and guidelines.
- Identify the highest-priority task from "$TASKS" that has "passes": false.
  This should be the one YOU decide has the highest priority - not necessarily the first in the list.
- Plan the implementation for that task. If unclear, ask for clarification ONLY if CAN_ASK_CLARIFY is true.
- Implement the task:
   - Make necessary code/file changes for the feature.
   - Use minimal changes to achieve the tasks acceptance criteria.
   - Adhere to coding guidelines from "$GUIDE".
- Run any tests or feedback loops specified in "$GUIDE" (e.g. unit tests, linters) to verify the feature.
   - If issues are found, fix them before proceeding.
- Once the feature is confirmed working, update the task in "$TASKS" by setting "passes": true.
- Append to "$PROG": $(ts) "Implemented <Task ID>: <short description about progress and implementation>".
- Create a git commit for this feature (use a descriptive commit message).
- If *all* tasks are now passes=true, output "<promise>COMPLETE</promise>".
EOF
}

guidar_prompt(){
  cat <<EOF
# Task: Guidar - Create/Update Project Guidelines.

- Do not include irrelevant info; keep it short and project-focused.

Steps:
- If project directory is not provided, ask for it
- Review its structure and key files (e.g., README, code files) to understand conventions, structure and important info.
- Ask the user for any additional project-specific guidelines (if something is unclear or missing).
- Compile a **$GUIDE** document that covers:
  - Instructions, tools and commands to use for running, testing, building, linting, etc.
  - Coding style conventions and best practices.
  - Architectural decisions and design patterns to follow.
  - Other project-specific rules (from existing docs or user input).
  - Links to other resources and actual files which can serve as examples for the patterns to use.
- Append to "$PROG": $(ts) "Guidelines created/updated."
- Output "<success>guidelines created</success>" when done.
EOF
}

story_prompt(){
  cat <<EOF
# Task: Storyteller - Generate User Stories from PRD and Tasks.

Steps:
- Read "$PRD" for overall context and "$TASKS" for the list of tasks.
- For each task in "$TASKS" (each task), write a concise **User Story** in the format:
   - As a <type of user>, I want <feature> so that <benefit>.
   - Include 2-3 acceptance criteria for each story (bullet points).
- Use the PRD to ensure each story captures the intended functionality and value.
- Save all user stories to a file (e.g., "$STORIES") in Markdown format.
   - Format as a list of user stories, clearly labeled or bullet-pointed.
- Append to "$PROG": $(ts) "User stories created."
- Output "<success>stories created</success>" when done.
EOF
}

projector_prompt(){
  cat <<EOF
# Task: Projector - Integrate New Information into Project.

Input:
- inbox dir: $INBOX (unstructured info files: notes, chats, meetings, etc)
- processed markers file: $PROCESSED (list of already processed files)

Steps:
- Determine unprocessed files by checking $PROCESSED and $INBOX.
- Summarize the key points or decisions from them.
- Identify any changes in requirements or new features mentioned in the new info.
- For each change/new requirement:
   - Update the "$PRD" if it changes the product scope or adds details.
   - If a new feature/task is identified, append it to "$TASKS" (with a new ID and passes=false).
   - If an existing task is affected (e.g., changed acceptance criteria), update its description or steps.
- Ensure not to duplicate tasks; maintain consistency in "$TASKS".
- If "$GUIDE" (guidelines) needs updates (e.g., new conventions or decisions), update it as well.
- Append to "$PROG": $(ts) "Project updated with new info: <brief summary> with bullet points about each update."
- Append processed filenames to $PROCESSED (one per line).
- (Optional) Prepare updates for JIRA or external trackers as needed, but do not execute them automatically.
- Output "<success>project updated</success>" when done.
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

cmd_prd(){
  [[ -n "${2:-}" ]] || die "usage: sir prd --prompt \"...\""
  ai "$(ctx)
$(prd_prompt "$2")"
}

cmd_rafael(){
  local n="${2:-10}"
  for ((i=1; i<=n; i++)); do
    echo "=== $i/$n ===" >&2
    local out
    out=$(ai "$(ctx)
$(rafael_prompt)") || return 1
    echo "$out"
    [[ "$out" == *"<error>"* ]] && return 1
    [[ "$out" == *"COMPLETE"* ]] && break
  done
}

cmd_guidar(){
  ai "$(ctx)
$(guidar_prompt "${2:-.}")"
}

cmd_storyteller(){
  ai "$(ctx)
$(story_prompt)"
}

cmd_projector(){
  ai "$(ctx)
$(projector_prompt)"
}

cmd_start(){
  local start_prompt
  start_prompt=$(cat <<EOF
$(ctx)

Available Commands:
-------------------
You are an AI assistant helping manage this project through SIR (Stateful Incremental Reasoner).
The user can ask you to perform any of the following operations, or others inputed as a custom prompt.

This is your context:
  $(ctx)

Predefined Commands:
1. **prd** - Create/Update PRD (Product Requirements Document) and Task List
   $(prd_prompt)

2. **rafael** - Implement Next Task (Rafael Wagyu)
   $(rafael_prompt)

3. **guidar** - Create/Update Project Guidelines
   $(guidar_prompt)

4. **storyteller** - Generate User Stories from PRD and Tasks
   $(story_prompt)

5. **projector** - Integrate New Information from Inbox
   $(projector_prompt)

What would you like to do?
EOF
)
  $AI_INTERACTIVE "$start_prompt"
}

########################################
# MAIN ENTRY POINT
########################################

usage(){
  cat <<EOF
SIR - Stateful Incremental Reasoner

Usage:
  sir init                     Init .sir structure
  sir prd --prompt "DESC"      Create PRD and tasks
  sir rafael [--iterations N]  Implement tasks (default 10)
  sir guidar [--dir PATH]      Generate guidelines
  sir storyteller              Create user stories
  sir projector                Process inbox files
  sir start                    Interactive mode

Examples:
  sir init
  sir prd --prompt "Build a Todo app"
  sir guidar --dir src
  sir rafael --iterations 5
EOF
}

main(){
  local ai_bin=${AI_CMD%% *}
  need "$ai_bin"
  case "${1:-}" in
    init) cmd_init ;;
    prd) cmd_prd "$@" ;;
    rafael) cmd_rafael "$@" ;;
    guidar) cmd_guidar "$@" ;;
    storyteller) cmd_storyteller ;;
    projector) cmd_projector ;;
    start) cmd_start ;;
    *) usage ;;
  esac
}

main "$@"
