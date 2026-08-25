---
estimation: 1d
status: Open
source: 2026-08-24 conversation — user ask
description: Add a `make mcp` target — bring up the demo cluster and keep it alive behind an MCP server so an AI client (Claude Code) can query it directly
---

# T20260824-339421: MCP server for the demo cluster (`make mcp`)

## Problem

- `make cluster` provisions a real MPP demo cluster (coordinator + standby +
  2 primaries + 2 mirrors, via `gpdemo` — see `cluster.sh`) inside a
  `docker run --rm` container, then the container exits once `cluster.sh`
  finishes printing `gp_segment_configuration` — there's no way to keep
  talking to it afterward.
- Goal: a `make mcp` target that brings the same demo cluster up, but keeps
  the container alive with an MCP server listening on a published port, so
  an MCP client (Claude Code) can register it and let an AI run queries /
  introspect schema against the live cluster directly — a natural extension
  of the talk's "build once, run anywhere" story into "now let an AI drive
  it."

## Scope for THIS task (initial pass)

1. Design note: MCP transport (Streamable HTTP — a port needs to be
   published across the container boundary, so stdio doesn't work here),
   tool set (at minimum: run SQL, list schemas/tables, describe table;
   consider surfacing `gp_segment_configuration` as a demo-flavored tool),
   and how the container stays alive (keep `cluster.sh`'s
   `provision-demo-cluster` as-is; add a new script that provisions, then
   runs the MCP server in the foreground instead of letting the container
   exit).
2. `make mcp` Makefile target — reuses `cluster.sh`'s provisioning (DRY, per
   this repo's Makefile philosophy: "every recipe is a `docker build` or
   `docker run ... <existing .sh>`"). Publish the MCP port to `127.0.0.1`
   only — the MCP server itself has no auth, so it must not bind `0.0.0.0`.
3. MVP MCP server implementation + connection wiring (coordinator port read
   from the running `gpdemo-env.sh`, `gpadmin` user, `postgres` db).
4. README section: `make mcp` usage + the `claude mcp add --transport http
   ...` registration command.
5. Pre-publish leakage scan must still pass
   (`synxdb-team/confidential/2026-cfp-coc-asia/leakage-scan.sh`) — this is
   a public repo.

## Done when

- Design note (transport, tool set, container-lifecycle approach) is
  written down.
- `make mcp` brings up the demo cluster + a working MCP server on a
  published localhost port.
- Claude Code can register it (`claude mcp add --transport http ...`) and
  successfully run a query against the live cluster.
- README documents the flow; leakage scan passes; CI still green.

## Out of scope (for now)

- Authentication/authorization on the MCP server (fine for a loopback-only
  local demo; would need real auth before ever binding beyond localhost).

## Dependencies

None.
