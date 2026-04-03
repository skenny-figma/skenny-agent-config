# Project Instructions

## Repository Context

This repo is the source of truth for Claude Code configuration.
Files here are symlinked into `~/.claude/` via `install.sh`.

- **Edit files in this repo**, not in `~/.claude/` directly
- Non-symlinked additions must be added to `install.sh`

## Multi-Phase Implementation Guidelines

When using `/research` to plan complex features, structure the "Next
Steps" section with explicit phase markers for multi-phase
implementations:

### Phase Marker Patterns

Use either of these patterns:
- `**Phase N: Description**` (bold inline)
- `### Phase N: Description` (heading level 3)

### Phase Granularity

- 3-7 phases is ideal (not too many small phases, not too few large ones)
- Each phase should be independently reviewable and testable
- Natural breakpoints: setup, implementation, testing, documentation
- Phases should build on each other sequentially

### Example Structure

```markdown
## Next Steps

**Phase 1: Foundation**
1. Create directory structure
2. Add configuration files
3. Set up dependencies

**Phase 2: Core Implementation**
4. Implement main feature logic
5. Add error handling
6. Create helper utilities

**Phase 3: Testing and Documentation**
7. Write unit tests
8. Add integration tests
9. Update README and documentation
```

### Benefits

- Review and test between phases
- Commit after each phase for clean history
- Pause and resume work easily
- Clear progress tracking via active tracking file
