---
name: split-commit
description: >
  Repackage branch into clean, tested, vertical commits. Triggers:
  'split commits', 'repackage commits', 'reorganize commits',
  'clean up branch history'. Not for single-commit branches — use
  /commit instead.
argument-hint: "[base-branch] [--test='command'] [--auto]"
user-invocable: true
allowed-tools:
  - Agent
  - Bash
  - Read
  - Glob
  - Grep
---

# Split Commit

Repackage a branch's changes into clean, vertical commits using
hunk-level precision. Pure orchestrator — two subagents handle
analysis and execution.

## Arguments

- `[base-branch]` — comparison base (default: `gt trunk` or
  `origin/HEAD` or `main`)
- `--test='command'` — test command to verify each commit compiles
- `--auto` — skip approval gate, execute plan immediately

## Step 1: Parse Args + Noop Check

Parse `$ARGUMENTS` for base branch, `--test`, and `--auto` flag.

Resolve base branch:

```bash
base=$(gt trunk 2>/dev/null || git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/||' || echo main)
```

Noop check — if branch has ≤1 commit, stop early:

```bash
count=$(git log --oneline "$base"..HEAD | wc -l | tr -d ' ')
```

If `count` ≤ 1: respond "Only $count commit(s) on this branch —
use /commit instead." and stop.

## Step 2: Analysis (Subagent)

Spawn analysis agent (`subagent_type=general-purpose`, `model=opus`):

```
Analyze this branch for vertical commit decomposition.

## Commands to Run
1. git log --oneline <base>..HEAD
2. git diff --stat <base>..HEAD
3. git diff <base>..HEAD (full diff)

## Grouping Rules
- Order: foundational → features → cleanup
- File A imports B → same commit or B earlier
- Config/lock files go with the feature that introduces the dep
- New types/interfaces go with first consumer
- Each commit should be independently compilable

## Test Command Detection
Auto-detect from: justfile, Makefile, package.json, Cargo.toml
(look for test/check targets).

## Output Format
Return a COMMIT_PLAN as structured text:

For each commit:
  type(scope): message
  Files: [list of full file paths]
  Partial hunks: [file:description of which hunks, if partial]
  Deps: [which commits must come before this one]
  Rationale: [why these changes belong together]

Also return TEST_COMMANDS if auto-detected.
Do NOT write any files.
```

## Step 3: Approval Gate

- If `--auto` flag is set → skip to Step 4
- Otherwise → display the commit plan and ask user to approve,
  reject, or request changes

## Step 4: Execution (Subagent)

Spawn execution agent (`subagent_type=general-purpose`,
`model=sonnet`):

```
Execute this commit split plan using git-surgeon techniques.

## Plan
<commit plan from analysis>

## Test Commands
<test commands from analysis, or "none">

## Git-Surgeon Reference
Read /Users/jim/workspace/claude/skills/git-surgeon/git-surgeon.md
for the hunk-level staging technique (patch building, git apply
--cached).

## Protocol

1. Collapse all commits to unstaged:
   git reset --soft <base> && git reset HEAD

2. For each planned commit (in order):
   a. List available hunks (parse git diff output)
   b. Identify which hunks match this commit's files/descriptions
   c. For full files: git add <file>
      For partial files: build patch and git apply --cached
   d. If test commands provided: run tests. On FAIL:
      - Look for missing dependency (import/type from a later
        commit)
      - Stage that hunk too, retry once
      - If still failing → STOP and report
   e. git commit -m "<type(scope): message>"

3. After last commit:
   - git diff --stat (check for remaining unstaged changes)
   - If unstaged changes remain: stage all, test, commit as
     "chore: clean up remaining changes"

4. Verify:
   - git status (should be clean)
   - git log --oneline <base>..HEAD (show final commit list)

Do NOT write any files outside of git operations.
```

## Step 5: Recovery

If the execution agent fails mid-way:
- Report which commits succeeded and which remain
- Do NOT attempt automatic recovery beyond the one-retry for
  missing deps in Step 4

## Step 6: Report

Show final commit list:

```bash
git log --oneline <base>..HEAD
```
