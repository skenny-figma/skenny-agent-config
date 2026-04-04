---
name: vibe
description: >
  Fully autonomous development workflow from prompt to commit.
  Chains research → implement → review → commit → submit.
  Triggers: /vibe, "vibe this", "autonomous workflow".
allowed-tools: Bash, Read, Glob, Skill, TaskCreate, TaskUpdate, TaskGet, TaskList
argument-hint: "<prompt> [--continue] [--dry-run]"
---

# Vibe

Run the full development pipeline from a single prompt.

## Plan Directory

@rules/blueprints.md.

## Arguments

- `<prompt>` — what to build (required unless `--continue`)
- `--continue` — resume a failed pipeline from last completed stage
- `--dry-run` — research only, stop before implement

## Pipeline

```
/research → /implement → /review → /report → /commit → /submit
```

Each stage verifies success before proceeding. Failures halt
with a clear report.

## Step 1: Parse Arguments

Extract from `$ARGUMENTS`:

- `<prompt>`: everything except flags
- `--continue`: boolean
- `--dry-run`: boolean

If no prompt and no `--continue` → tell user:
`/vibe <what to build>`, stop.

## Step 2: Resume Check

If `--continue`:

1. `TaskList()` → find task with `metadata.type == "vibe"`
   and `status == "in_progress"`
2. If found → read `metadata.vibe_stage` to determine resume point
3. Read `metadata.vibe_prompt` as the prompt
4. Skip to the stage after `vibe_stage` (see Step 4)
5. If not found → tell user no pipeline to resume, stop

## Step 3: Create Pipeline Tracker

```
TaskCreate(
  subject: "Vibe: <prompt (truncated to 60 chars)>",
  description: "Autonomous pipeline for: <full prompt>",
  activeForm: "Vibing: <prompt (truncated to 40 chars)>",
  metadata: {
    type: "vibe",
    vibe_prompt: "<full prompt>",
    vibe_stage: "started",
    priority: 1
  }
)
TaskUpdate(taskId, status: "in_progress")
```

## Step 4: Execute Pipeline

Run stages sequentially. After each stage succeeds, update
`metadata.vibe_stage` via TaskUpdate before proceeding.

### Stage 1: Research

```
Skill("research", args="<prompt>")
```

**Verify**: Plan file exists in `~/workspace/blueprints/<project>/`.
Check via `{ ls -t ~/workspace/blueprints/<project>/spec/*.md ~/workspace/blueprints/<project>/plan/*.md ~/workspace/blueprints/<project>/review/*.md; } 2>/dev/null | head -1`.
**Update**: `TaskUpdate(trackerId, metadata: { vibe_stage: "research" })`
**Report**: `[1/6] Researched: plan at <path>`

If `--dry-run` → stop here. Report plan file, suggest
`/implement` or `/vibe --continue` when ready.

### Stage 2: Implement

```
Skill("implement", args="--no-report")
```

**Verify**: `TaskList()` → all children of epic have
`status == "completed"`.
**Update**: `TaskUpdate(trackerId, metadata: { vibe_stage: "implement" })`
**Report**: `[2/6] Implemented: N/N tasks completed`

If some tasks failed, report failures but continue to commit
if any code was changed (`git diff --stat` is non-empty).

### Stage 3: Review

```
Skill("review")
```

**Verify**: Review file exists via
`ls -t ~/workspace/blueprints/<project>/review/*.md | head -1`.
**Update**: `TaskUpdate(trackerId, metadata: { vibe_stage: "review" })`
**Report**: `[3/6] Reviewed: findings at <path>`

If review fails, log warning but continue to report (non-blocking).

### Stage 4: Report

```
Skill("report")
```

**Verify**: Report file exists via
`ls -t ~/workspace/blueprints/<project>/report/*.md | head -1`.
**Update**: `TaskUpdate(trackerId, metadata: { vibe_stage: "report" })`
**Report**: `[4/6] Report: <path>`

If report fails, log warning but continue to commit (non-blocking).

### Stage 5: Commit

Check `git diff --stat` first. If empty → skip, report
`[5/6] Commit: skipped (no changes)`.

```
Skill("commit")
```

**Verify**: `git log -1 --oneline` shows a new commit.
**Update**: `TaskUpdate(trackerId, metadata: { vibe_stage: "commit" })`
**Report**: `[5/6] Committed: <commit oneline>`

### Stage 6: Submit

```
Skill("submit")
```

**Verify**: `gt ls` shows PR created/updated.
**Update**: `TaskUpdate(trackerId, metadata: { vibe_stage: "submit" })`
**Report**: `[6/6] Submitted: PR created/updated`

If submit fails, log warning (non-blocking) — code is committed.

## Step 5: Finalize

```
TaskUpdate(trackerId, status: "completed")
```

Report full summary:

```
Pipeline complete:
[1/6] Researched: plan at <path>
[2/6] Implemented: N/N tasks completed
[3/6] Reviewed: findings at <path>
[4/6] Report: <path>
[5/6] Committed: <commit oneline>
[6/6] Submitted: PR created/updated
```

## Error Handling

If ANY stage fails:

1. Do NOT update `vibe_stage` (it stays at last successful stage)
2. Leave tracker task in_progress
3. Report:
   ```
   Pipeline halted at stage N (<stage-name>).
   Error: <details>

   Completed:
   [1/6] Researched: ...
   [2/6] Implemented: ...

   Resume: `/vibe --continue`
   Or run manually: `/<failed-skill> [args]`
   ```

## Stage Count

- Default: 6 stages (`[N/6]`)
- With `--dry-run`: 1 stage (`[N/1]`)

Adjust the `[N/M]` denominator based on active flags.
