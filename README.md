# SIR - **Stateful Incremental Reasoner** or **Supreme Intelligence for Reasoning**

AI project assistant. Single bash script.

## Install

```bash
# In your project directory
curl -o sir.sh https://raw.githubusercontent.com/andreiciceu/sir/main/sir.sh
chmod +x sir.sh
```

## Setup

```bash
# 1. Init SIR
./sir.sh init

# 2. Start interactive mode (launches OpenCode)
./sir.sh start
```

That's it. OpenCode now has full project context + SIR commands available.

## Usage

In OpenCode interactive mode, ask for any of these:

**prd** - Create PRD and tasks from description
**rafael** - Implement next pending task
**guidar** - Generate project guidelines  
**storyteller** - Create user stories
**projector** - Process inbox files

Example:

```
> guidar
> prd - build a REST API for user management
> rafael
```

## Commands (CLI)

```bash
./sir.sh init                    # Init .sir structure
./sir.sh prd --prompt "DESC"     # Create PRD
./sir.sh rafael [--iterations N] # Implement tasks (default 10)
./sir.sh guidar [--dir PATH]     # Generate guidelines
./sir.sh storyteller             # Create stories
./sir.sh projector               # Process inbox
./sir.sh start                   # Interactive mode
```

## How It Works

Creates `.sir/memory/` with:

- `PRD.md` - requirements
- `tasks.json` - task list (pass/fail)
- `GUIDELINES.md` - project conventions
- `stories.md` - user stories
- `progress.txt` - changelog
- `inbox/` - drop notes/feedback here

Rafael implements tasks, runs tests, commits automatically.

## Config

```bash
# Different AI backend
AI_CMD="claude -p" ./sir.sh rafael

# Custom model for interactive
AI_INTERACTIVE="opencode --model gpt-4" ./sir.sh start

# Disable questions
CAN_ASK_CLARIFY=false ./sir.sh prd --prompt "..."
```

## License

MIT
