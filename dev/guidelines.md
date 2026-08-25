# Developer Guidelines

These guidelines apply to all work in the 2026-cfp-coc-asia project.

## Core Principles

- **KISS** / **DRY** — keep it simple, don't repeat yourself
- **Idempotent, sourceable, function-wrapped** bash scripts
- **Fix the root cause, not the symptom**
- Makefile targets are pure orchestration: every recipe is a `docker build`
  or `docker run ... <existing .sh>` — the `.sh` files stay the single
  source of truth, never duplicate their logic into a Makefile recipe

## Content & Privacy Guidelines

This is a **public** repo (companion to a conference talk) — hold every
file to this bar before committing:

- **No secrets.** No API keys, tokens, passwords, or `.env` contents.
- **No PII beyond self-disclosure.**
- **Builds of, not a fork of, Apache Cloudberry (Incubating).** Keep that
  framing accurate in docs/README — see the existing README.md wording.
- **Pre-publish gate (every push):** `synxdb-team/confidential/2026-cfp-coc-asia/leakage-scan.sh <this-repo>` must exit 0 before pushing.

## Branch and Merge Policy

The `main` branch is the source of truth. Never push directly to `main`.

1. **Create a feature branch** — all changes go through a feature branch, no exceptions
2. **Branch naming**: `t{task-id}-short-description` for tracked tasks; `fix/`, `feat/`, `docs/` prefixes for untracked work
3. **Open a PR** — clear summary and test plan
4. **CI must pass** — the arm64 build → 9-distro smoke matrix → cluster job (`.github/workflows/build.yml`) must be green
5. **Merge method** — rebase and merge (`bash ~/.claude/skills/_gh/gh.sh pr merge --rebase --delete-branch`)
6. **Delete the branch after merge**

## TODO Lifecycle

Tasks live as individual files — the filesystem is the index. **Never mirror the index in CLAUDE.md.**

- **Open tasks**: `dev/TODO/*.md`
- **Parked tasks**: `dev/PARKING/*.md`
- **Completed**: `dev/JOURNAL/yyyy-mm-dd-{id}-slug.md`

### Task ID Format

```
TYYYYMMDD-NNNNNN
```

Generate with the shared helper — single source of truth, so every skill that creates a task uses the same generator and the same collision-avoidance rules:

```bash
bash ~/.claude/skills/_taskid/new.sh --check ./dev
```

Pass `--check <dev-dir>` so the helper rejects any ID that already exists under `dev/{TODO,PARKING,JOURNAL}/` and retries. Do NOT inline the `printf ... /dev/urandom ...` command in a new skill or script — add a call to this helper instead.

### Task File Header

Task metadata uses **YAML frontmatter** (`---` … `---` at the top of the file), same convention as `SKILL.md` files in `synx-skills`. The H1 title follows.

```markdown
---
estimation: {30m|1h|2h|4h|1d|2d|1w|2w}
status: {Open|Design|Coding|Review|Blocked by T{id}}
source: {GitHub issue, upstream link, or process note}
description: {One-line summary}
---

# T{ID}: {Title}
```

### Status Flow

```
Open → Design → Coding → Review → Done
         ↕                          ↕
    Blocked by T{id}             Parked
```

- **Done** = `git mv` from `dev/TODO/` to `dev/JOURNAL/yyyy-mm-dd-{id}-slug.md`. Include this move in the implementing PR.
- **Parked** = `git mv` from `dev/TODO/` to `dev/PARKING/`.

### Branch Rule

**Do NOT update CLAUDE.md when journaling.** The `dev/JOURNAL/` folder IS the index. Mirroring it in CLAUDE.md duplicates content, eats the auto-loaded context budget, and creates merge conflicts on every completed task. CLAUDE.md only changes when the project's overall structure changes.

## Script Standards

```bash
#!/usr/bin/env bash
set -euo pipefail

function my-operation() {
  local param="${1:-default-value}"
  # Idempotent body
}

# Run only if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  my-operation "$@"
fi
```

Rules: wrap logic in functions, make scripts sourceable, keep operations idempotent, use `set -euo pipefail`.

## Documentation

- **Task tracking**: `dev/TODO/` (active), `dev/JOURNAL/` (completed)
- **Inline comments**: only where logic isn't self-evident
- **Commit messages**: conventional commits format
- **Prefer bullets over paragraphs**: chunk information into bullet points, short lists, and tables so a reader can scan and find the one fact they need — don't bury it inside a paragraph. Reserve prose for narrative that genuinely doesn't decompose (a root-cause story, a rationale). Applies to README, guidelines, task files, and JOURNAL entries alike.
