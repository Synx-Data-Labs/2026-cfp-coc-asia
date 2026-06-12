#!/usr/bin/env bash
# Package the staged tree into arm64 RPM + DEB from a single build (Apache-2.0, no EULA).
set -euo pipefail

package-synxdb-ce() {
  local prefix="/usr/local/synxdb-ce" out="/work/dist"
  local name="synxdb-ce" version="${PKG_VERSION:-2.1.0}"
  mkdir -p "$out"
  gem list fpm -i >/dev/null 2>&1 || gem install --no-document fpm
  for t in rpm deb; do
    fpm -s dir -t "$t" -n "$name" -v "$version" -a arm64 \
      --license "Apache-2.0" --description "Apache Cloudberry (Incubating) core — SynxDB CE" \
      --prefix "$prefix" -C "$prefix" -p "$out/" .
  done
  ls -l "$out"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then package-synxdb-ce "$@"; fi
