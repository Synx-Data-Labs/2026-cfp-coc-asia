#!/usr/bin/env bash
# Portability gate (HARD): no unresolved non-glibc shared-lib deps, AND the binary
# loads + runs on this distro (postgres --version). These prove the build-once-run-
# anywhere claim. A standalone Cloudberry postmaster can't start without MPP/dbid
# context, so the per-distro functional check stops here; the real server-up +
# query proof is the cluster demo (cluster.sh / `make cluster`).
set -uo pipefail

prefix="/usr/local/synxdb-ce"

portability-gate() {
  echo "== ldd gate: no unresolved shared-lib deps =="
  local bad=0
  while IFS= read -r f; do
    if ldd "$f" 2>/dev/null | grep -q "not found"; then
      echo "❌ unresolved dep in $f:"; ldd "$f" | grep "not found"; bad=1
    fi
  done < <(find "$prefix/bin" "$prefix/lib" -type f -executable 2>/dev/null)
  [ "$bad" -eq 0 ] || { echo "❌ portability gate failed"; return 1; }
  echo "✅ no unresolved deps — glibc is the only external dependency"
}

version-check() {
  echo "== binary loads + runs here ($(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}")) =="
  "$prefix/bin/postgres" --version
}

run-tests() {
  # Fail loud if the package didn't actually install — otherwise the ldd gate
  # iterates over an empty prefix and "passes" vacuously, masking a broken install.
  [ -x "$prefix/bin/postgres" ] || { echo "❌ install incomplete — $prefix/bin/postgres missing"; return 1; }
  portability-gate || return 1
  version-check    || return 1
  return 0
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then run-tests "$@"; fi
