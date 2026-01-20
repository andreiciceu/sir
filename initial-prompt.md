SIR — Stateful Incremental Reasoner (Simple Intelligence for Reasoning)

Build a very simple shell script, with various tools that leverage the use of AI(Claude Code), to help with daily development and project management tasks.
It'll be built incrementally, so split workload into many smaller tasks that can be acomplished independently, to avoid context filling up.

Constraints:

- It should run on a macOS device, with bash
- It should be agnostic of what coding agent we use (define at the top of the file various configs, prompt parts, aliases that can easily be replaced)
- All tasks will use the same config, defined at the top of the bash file, which can be changed per project; it includes path to memory, guidelines, PRD, tasks, etc.
- It should be very simple, mostly prompts and using the above abstraction
- It should be one single bash file with a clean & clear structure;
- The repo where this tool is built can have it's own PRD/tasks/memory/etc

Guidelines:

- In all interactions and outputs, be extremly concise and sacrifice grammar for the sake of concision; you should do this when generating the plan, and the tool itself should also do this
- All the tools, code, prompts created should be concise, short and minimal to keep efficiency
- Value clarity, simplicity, minimalism

Tools:

# 1. PRD Creator

- Takes either a prompt or a path to a folder which contains a lot of information (possible unstructured text files, maybe images), analyzes it, asks further clarification questions until everything is clear
- Outputs an PRD (Product Requirements Document) in markdown format and saves it in a file
- Outputs a tasks file, a feature list which is the PRD but split into smaller pieces. read this for best usage: https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents

# 2. Rafael Wagyu

- This is the engine than we'll use to build everything; it's a refined version of Ralph Wiggum; read this for context and improvements to this https://www.aihero.dev/tips-for-ai-coding-with-ralph-wiggum
- It takes as input (context):
  - one or more files as GUIDELINES, (basically the product documentaiton), which acts as a memory about coding guideliens, docs, examples, relevant files and information about the project
  - the PRD and tasks files from the PRD creator
  - a progess.txt which serves as the activity log for Rafael
- It outputs (or edits):
  - relevant files/folders to implement the tasks
  - the updated (appended progress.txt)
  - the updated tasks file

# 3. Guidar

(Will be created later) with PRD creator and Rafael.
Would basically analyze the project(repository), ask questions if needed and ask for any special information then create a GUIDELINES file (or if too long a folder with multiple docs).

# 4. Storyteller

(Will be created later) with PRD creator and Rafael.
Creates from PRD and tasks a list of User Stories for each tasks.
Prepare those to be sent to JIRA after user confirmation (for each).

# 5. Projector

(Will be created later) with PRD creator and Rafael.
Would keep track of a feature/initiative in a large project and keep everything in sync (JIRA, PRD, user stories, tasks), where multiple people are involved.
The project will first start from a PRD, but then (as a project's life is), new stuff come in, new discussions, meetings, decisions, etc.
Those new information will be captured in various file formats (meeting notes, chat discussions, comments, etc.)
The tool will process new information, keep track of what was processed, and then append to the log with a summary of the updates, and update PRD, tasks, stories, etc.
Would be nice to actually update JIRA tasks after user confirmation.

# 6. Initiator

This is the tool, one-liner, that initiates or updated this whole tooling inside a folder.

When running in a new repo/project, we'd basically copy paste the bash file, and run ./sir init, which will create the .sir folder with the structure
Basically, for an existing project and a new feature, we'd run:
Guidar, PRD Creator, Storyteller; then start Rafael; then run Projector whenever there is an update.

---
