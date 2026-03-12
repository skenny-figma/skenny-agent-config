---
name: git-surgeon
description: "Non-interactive hunk-level git operations — stage, unstage, discard by hunk ID."
user-invocable: false
---

# Git Surgeon

Non-interactive hunk-level staging, unstaging, and discarding using
standard git commands and `shasum` for hunk identification.

## Hunk ID Generation

Parse `git diff` (unstaged) or `git diff --cached` (staged) output.
Each hunk begins with `@@ -a,b +c,d @@`. Generate a stable 7-char
hex ID:

```bash
echo -n "<file-path>:<full-hunk-content>" | shasum | cut -c1-7
```

Where `<full-hunk-content>` is everything from the `@@` line through
the last line before the next hunk or file header.

**Collision handling:** If two hunks produce the same ID, append
`-2`, `-3`, etc. in order of appearance.

**IDs are ephemeral.** They shift whenever the diff changes. Always
re-list before operating.

## Operations

### List Hunks

Parse `git diff` output. For each hunk, extract file path, line
stats, and first changed line as preview. Output a table:

```
ID       File                    Stats    Preview
a1b2c3d  src/auth.ts             +5/-2    + const token = jwt.sign(...)
e4f5g6h  src/auth.ts             +1/-1    - return null
1234567  lib/utils.py            +12/-0   + def retry(fn, attempts=3):
```

For staged hunks, use `git diff --cached` instead.

### Show Hunk

Given an ID from the list, display the full hunk diff content
including the `@@` header and all context/change lines.

### Stage Hunk(s)

Extract target hunk(s) as a valid patch and apply to the index:

```bash
# Build patch with required headers:
# 1. diff --git a/<file> b/<file>
# 2. --- a/<file>
# 3. +++ b/<file>
# 4. @@ ... @@ hunk header + content

# Apply to index only (stages without modifying working tree)
echo "$patch" | git apply --cached
```

The patch **must** include the `diff --git` header, `--- a/file` and
`+++ b/file` lines, and the `@@ ... @@` hunk header with content.
Without all four parts, `git apply` will reject it.

### Unstage Hunk(s)

Same approach using staged diff as source, applied in reverse:

```bash
# Extract from staged diff
git diff --cached -- <file>

# Build patch for target hunk(s), then reverse-apply
echo "$patch" | git apply --cached --reverse
```

### Discard Hunk(s)

Extract from working tree diff, reverse-apply to working tree:

```bash
# Extract from unstaged diff
git diff -- <file>

# Build patch for target hunk(s), then reverse-apply to working tree
echo "$patch" | git apply --reverse
```

**Warning:** Discard is destructive and cannot be undone.

## Workflow Examples

### Selective Staging

```
1. List hunks:        parse `git diff` → table with IDs
2. Show hunk:         display full content of hunk `a1b2c3d`
3. Stage hunk:        build patch for `a1b2c3d`, `git apply --cached`
4. Commit:            `git commit -m "..."`
```

### Partial File (3 hunks, stage 2)

```
1. List hunks:        file shows 3 hunks: a1b2c3d, e4f5g6h, 1234567
2. Stage two:         build combined patch with a1b2c3d + 1234567
3. Verify:            `git diff --cached -- <file>` shows 2 hunks
4. Commit:            staged hunks committed, e4f5g6h remains unstaged
```

### Unstage Mistake

```
1. List staged hunks: parse `git diff --cached` → table with IDs
2. Identify mistake:  hunk e4f5g6h was staged by accident
3. Unstage:           build patch from cached diff, `git apply --cached --reverse`
4. Verify:            `git diff --cached` no longer shows that hunk
```

## Troubleshooting

- **"ID not found"** — The diff changed since listing. Re-run list
  to get current IDs.
- **Duplicate IDs across files** — Collision handling adds `-2`,
  `-3` suffixes. Use the suffixed ID.
- **`git apply` fails** — Verify the patch includes all four
  required parts: `diff --git` header, `---`/`+++` lines, and `@@`
  hunk header with content. Missing any part causes rejection.
- **Hunk won't apply after other operations** — Context lines may
  have shifted. Re-list and re-extract the hunk from fresh diff
  output.
