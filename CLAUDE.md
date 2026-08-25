# 2026-cfp-coc-asia

Companion repo for the Community Over Code Asia 2026 talk "Build Once, Run
on Any Linux: A Truly Portable Binary Distribution for Apache Cloudberry
(Incubating)". Builds Apache Cloudberry's core from public upstream source
into a portable arm64 Linux binary (RPM + DEB), tests it across a 9-distro
matrix, and stands up a real MPP demo cluster (`make cluster`). See
[README.md](README.md) for the full build/test/cluster flow.

---

## Guidelines

**You MUST read and follow [dev/guidelines.md](dev/guidelines.md) before making any changes.**

**Conventions**: see `/repo-conventions` skill — it defines CLAUDE.md/guidelines.md structure and the dev/ TODO lifecycle.

---

## Task Tracking

- **Open tasks**: `dev/TODO/*.md` — one file per task
- **Parked tasks**: `dev/PARKING/*.md` — valid but not actionable now
- **Completed tasks / journal**: `dev/JOURNAL/*.md` — permanent record (the folder IS the index; do NOT mirror it here)
- See [dev/guidelines.md](dev/guidelines.md) **TODO Lifecycle** for task ID format, status flow, and procedures
- **Do NOT update CLAUDE.md when journaling** — only when the project's overall structure changes

---

## Context Budget

Auto-loaded files consume the context window. Keep them small.

| File | Max Lines | Max Size | Action if exceeded |
|------|-----------|----------|--------------------|
| `~/CLAUDE.md` | 0 | 0 KB | Should not exist — removed by design |
| Project `CLAUDE.md` | 50 | 3 KB | This file should stay small — details live in TODO/JOURNAL files |
| `dev/guidelines.md` | 200 | 8 KB | Split into separate files |
| Memory files (total) | 100 | 5 KB | Archive stale memories |

**At the start of each session**, check if any file exceeds its cap and warn the user before proceeding.
