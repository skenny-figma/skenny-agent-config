---
name: research
description: >
  Research topics, investigate codebases, and create
  implementation plans.
  Triggers: 'research', 'investigate', 'explore'.
allowed-tools: Bash, Read, Write, Task, SendMessage, TaskCreate, TaskUpdate, TaskGet, TaskList, TeamCreate, TeamDelete
argument-hint: "<topic or question> | <task-id> | --continue | --discard | --team | --depth <medium|high|max>"
---

# Research

Orchestrate research via native tasks and Task delegation.

## Arguments

- `<topic>` — new research on this topic
- `<task-id>` — continue existing research task
- `--continue` — resume most recent research (checks task list
  first, then falls back to most recent plan file, then archive)
- `--discard [slug]` — delete the most recent (or specified) plan
  file without preparing it
- `--team` — force team mode for parallel multi-topic research
- `--depth <level>` — control research thoroughness (default: medium)
  - `medium` — key files, file paths without snippets, 3-5 phases
  - `high` — all relevant files, 2-level call chains, line refs
    with brief code context, dependency chains, 5-7 phases
  - `max` — exhaustive: all touched modules, full call chains,
    full dependency graph, annotated snippets, cross-reference
    matrix, 7+ phases with sub-steps and verification criteria

## Plan Directory

Plans are scoped by project to avoid collisions across repos:
`~/.claude/plans/<project>/` where `<project>` is the `basename`
of the git root directory (or cwd if not in a repo).

Archived plans (consumed by `/implement`) live in the `archive/`
subdirectory and can be restored via `--continue`.

Create the directory on first write: `mkdir -p ~/.claude/plans/<project>/`

## Slug Generation

Generate a kebab-case slug from the topic: lowercase, strip filler
words [a, an, the, for, with, and, or, to, in, of, on, by, is,
it, be, as, at, do], replace non-alphanumeric runs with hyphens,
max 50 chars truncated on word boundary.

## Plan File Format

```markdown
---
topic: <original topic text>
project: <absolute path to current working directory>
created: <ISO 8601 timestamp>
status: draft | prepared
depth: <medium|high|max>
---

<full research findings in standard structure>
```

## Workflow

### New Research

1. Create task:
   ```
   TaskCreate(
     subject: "Research: <topic>",
     description: "## Acceptance Criteria\n- Findings written to ~/.claude/plans/<project>/<slug>.md\n- Structured as Current State, Recommendation, and phased Next Steps\n- Each phase is independently actionable",
     activeForm: "Researching <topic>",
     metadata: { type: "task", priority: 2 }
   )
   ```
2. `TaskUpdate(taskId, status: "in_progress")`
3. Parse flags and classify topics from $ARGUMENTS:
   - Extract `--depth <level>` if present (medium|high|max,
     default: medium). Error if value is not one of the three.
   - Extract `--team` flag if present.
   - Strip extracted flags from $ARGUMENTS; remainder is topic text.
   - Classify remaining topic text to determine mode:
     - Numbered list items (`1.` / `2.` / `-` / `*`) → extract
       each as a topic
     - Comma-separated phrases with "and" → split on commas
     - Multiple sentences ending in `?` → each is a topic

   If 2+ topics detected OR `--team` flag → **Team Mode** (step 4b)
   Otherwise → **Solo Mode** (step 4a)

4. Spawn research agent(s).

   **a) Solo Mode** — spawn a single Task (subagent_type=Explore,
   model=opus) using the solo prompt template below.

   **b) Team Mode** — create a Claude team for coordinated
   parallel research.

   1. Create team: `TeamCreate(team_name="research-<slug>")`
      Read team config:
      `~/.claude/teams/research-<slug>/config.json`
      → extract your `name` field as `<lead-name>`
   2. Create per-topic tasks under the main research task.
      Cap at 5 topics; group excess together.
      ```
      TaskCreate(
        subject: "Research: <topic-N>",
        description: "<topic text>",
        activeForm: "Researching <topic-N>",
        metadata: { type: "task", parent_id: "<main-task-id>" }
      )
      ```
   3. Spawn ALL workers in a SINGLE message using the team
      worker prompt template below. One Task call per topic:
      ```
      Task(
        subagent_type="general-purpose",
        team_name="research-<slug>",
        name="researcher-<N>",
        model=opus,
        prompt=<team worker prompt>
      )
      ```
      CRITICAL: All Task calls in ONE message for true
      parallelism.
   4. Wait for completion — track `completed_count` from
      worker SendMessage notifications. When all done →
      proceed to aggregation. If a worker goes idle without
      completing → check TaskList, mark stuck tasks, proceed
      when all non-stuck workers done.
   5. Aggregate findings (see Team Mode Aggregation below).
   6. Cleanup: `SendMessage(type="shutdown_request")` to each
      worker. After all acknowledge → `TeamDelete`.

5. Store findings:
   a. Write plan file:
      `Write("~/.claude/plans/<project>/<slug>.md",
        <frontmatter + findings>)`
   b. Store in task:
      `TaskUpdate(taskId, metadata: {
        design: "<findings>", plan_file: "<slug>.md",
        depth: "<level>" })`
   For Team Mode, run aggregation before storing.

6. Report results (see Output Format)

### Continue Research

1. Resolve source:
   - If `$ARGUMENTS` matches a task ID → `TaskGet(taskId)`
   - If `--continue` → `TaskList()`, find first in_progress
     "Research:" task. If none found, find most recent plan file
     in `~/.claude/plans/<project>/` via
     `ls -t ~/.claude/plans/<project>/*.md | head -1`
   - If no active plan found, check archive:
     `ls -t ~/.claude/plans/<project>/archive/*.md | head -1`
     If found, copy it back to active:
     `cp ~/.claude/plans/<project>/archive/<file> ~/.claude/plans/<project>/`
     Report: "Restored archived plan: `<filename>`"
2. Load existing context:
   - From task: read `metadata.design` and `metadata.depth`
   - From plan file: `Read` the file content, extract `depth`
     from frontmatter (skip rest of frontmatter)
   - If user provides `--depth` flag, use it (override).
     Otherwise use the stored depth (default: medium).
3. Spawn Explore agent with previous findings prepended:
   "Previous findings:\n<existing-design>\n\n
   <inject the depth block for the resolved depth level>\n\n
   Continue the research focusing on: <new-instructions>"
4. Update both stores:
   a. `Write` updated findings to plan file
   b. `TaskUpdate(taskId, metadata: { design: "<updated>" })`
5. Report results

### Discard Plan

1. Determine `<project>`:
   `basename $(git rev-parse --show-toplevel 2>/dev/null || pwd)`
2. If slug provided after `--discard`:
   - Delete `~/.claude/plans/<project>/<slug>.md` (try
     with/without .md extension, partial glob match)
3. If no slug → delete most recent:
   `ls -t ~/.claude/plans/<project>/*.md | head -1`
   Then delete it.
4. Report: "Discarded plan: `<filename>`"

## Prompt Templates

### Solo Prompt

Spawn Task (subagent_type=Explore, model=opus) with:

```
Research <topic> thoroughly. Return your COMPLETE findings as
text output (do NOT write files).

<inject the depth block for the selected --depth level>

Structure:

1. **Current State**: What exists now (files, patterns, architecture)
2. **Recommendation**: Suggested approach with rationale
3. **Next Steps**: 3-7 phases, each independently testable.

Each step must include:
- **Action**: verb + target (what to do)
- **Location**: file path with line ref when modifying existing code
- **Context**: why, when non-obvious
- **Done signal**: how to verify completion

Example step: "Add rate-limit middleware to `src/api/router.ts:45`
— wrap existing handler with `rateLimit()`. Verify: returns 429
after 100 req/min."

**Phase 1: <Description>**
1. <step with action, location, context, done signal>
2. ...

**Phase 2: <Description>**
3. ...
```

### Team Worker Prompt

Team workers use `subagent_type=general-purpose` (not Explore)
so they can use SendMessage for coordination.

```
You are a research worker on a team. Research your assigned
topic and report back.

## Your Topic
<topic text>

## Overall Context
<original user request>

## Your Task ID
<task-id>

## Protocol

1. Claim your task:
   TaskUpdate(taskId="<task-id>", status="in_progress",
     owner="researcher-<N>")

2. Research thoroughly. Use Read, Grep, Glob, Bash for
   investigation. Return findings as text (do NOT write files).
   <inject the depth block for the selected --depth level>

3. Structure findings:
   **Current State**: What exists now
   **Recommendation**: Suggested approach
   **Next Steps**: 3-7 phases, each independently testable.
   Each step: action (verb + target), location (file path
   with line ref), context (why, if non-obvious), done signal
   (how to verify).

4. When done, complete the task with your findings:
   TaskUpdate(taskId="<task-id>", status="completed",
     metadata={ notes: "<your full findings>" })

5. Send completion message to team lead:
   SendMessage(type="message", recipient="<lead-name>",
     content="Completed: <brief summary of findings>",
     summary="Completed topic <N>")

6. Wait for shutdown request. When received, approve it.

## Rules
- Only research — do NOT modify any files
- If blocked, report via SendMessage instead of guessing
- Do NOT work on other topics after completing yours
```

## Depth Levels

Both solo and team worker prompts contain a placeholder:
`<inject the depth block for the selected --depth level>`.
Replace it with the block matching the parsed `--depth` value:

**medium** (default):
```
Read key files to understand architecture. Report file paths
without code snippets. Produce 3-5 phases in Next Steps.
```

**high**:
```
Read all relevant files and trace call chains 2 levels deep.
Include line references and brief code context for non-obvious
patterns. Map dependency chains between affected modules.
Produce 5-7 phases in Next Steps, each independently testable.
```

**max**:
```
Exhaustive research. Read all touched modules, trace every call
chain to its origin, map the full dependency graph. Provide
annotated code snippets for all findings. Build a cross-reference
matrix of callers, shared state, and coupling between components.
Produce 7+ phases in Next Steps with sub-steps and explicit
verification criteria per phase.
```

## Team Mode Aggregation

After all workers send completion messages (or stuck detection
fires), collect findings from each worker's task metadata:

For each topic task: `TaskGet(taskId)` → extract `metadata.notes`

Then combine:

1. Prefix each topic's findings with **Topic N: <name>**
2. Detect cross-topic connections (shared files, dependencies,
   conflicts)
3. Renumber phases globally across all topics (Phase 1-N
   sequential) so /implement can parse them
4. If cross-topic connections found, add a **Cross-Topic
   Connections** section at the top

## Output Format

**Research Task**: #<id>

**Key Findings**:
- Bullet points of critical discoveries

**Recommendation**: <one paragraph>

**Plan**: `~/.claude/plans/<project>/<slug>.md` — review/edit in `$EDITOR`
before `/implement`.

**Next**: `/implement` to create tasks, edit the plan file first,
or `/research --discard` if not needed.
