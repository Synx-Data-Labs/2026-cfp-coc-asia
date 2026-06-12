#!/usr/bin/env bash
# (1) portability gate: no surprise shared-lib deps; (2) install + smoke SELECT version().
set -euo pipefail

portability-gate() {
  local prefix="/usr/local/synxdb-ce"
  echo "== ldd / readelf gate =="
  local bad=0
  while IFS= read -r f; do
    if ldd "$f" 2>/dev/null | grep -q "not found"; then
      echo "MISSING dep in $f:"; ldd "$f" | grep "not found"; bad=1
    fi
  done < <(find "$prefix/bin" "$prefix/lib" -type f -executable 2>/dev/null)
  [ "$bad" -eq 0 ] && echo "✅ no missing shared-lib deps" || { echo "❌ portability gate failed"; return 1; }
}

smoke() {
  local prefix="/usr/local/synxdb-ce"
  source "$prefix/greenplum_path.sh" 2>/dev/null || export PATH="$prefix/bin:$PATH"
  useradd -m gpadmin 2>/dev/null || true
  su - gpadmin -c "
    export PATH=$prefix/bin:\$PATH
    initdb -D /tmp/demo &&
    pg_ctl -D /tmp/demo -l /tmp/demo/log start &&
    sleep 3 &&
    psql -d postgres -c 'SELECT version();'
  "
}

run-tests() { portability-gate && smoke; }
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then run-tests "$@"; fi
