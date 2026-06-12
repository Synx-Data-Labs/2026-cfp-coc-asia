#!/usr/bin/env bash
# Package the staged tree into arm64 RPM + DEB from a single build (Apache-2.0, no EULA).
set -euo pipefail

package-synxdb-ce() {
  local prefix="/usr/local/synxdb-ce" out="/work/dist"
  local name="synxdb-ce" version="${PKG_VERSION:-2.1.0}"
  mkdir -p "$out"
  gem list fpm -i >/dev/null 2>&1 || gem install --no-document fpm
  for t in rpm deb; do
    # rpmbuild emits /usr/lib/.build-id/* symlinks keyed on each ELF's GNU build-id.
    # Our vendored libs are byte-identical copies of the build floor's system libs, so
    # their build-ids collide with the base packages that own those paths — the RPM then
    # conflicts with pcre2/libselinux/... on the build-floor distro. Suppress the links
    # (they point outside our --prefix anyway). DEB has no equivalent footgun.
    local rpm_only=()
    [ "$t" = rpm ] && rpm_only=(--rpm-rpmbuild-define '_build_id_links none')
    fpm -s dir -t "$t" -n "$name" -v "$version" -a arm64 \
      --license "Apache-2.0" --description "Apache Cloudberry (Incubating) core — SynxDB CE" \
      "${rpm_only[@]}" \
      --prefix "$prefix" -C "$prefix" -p "$out/" .
  done
  ls -l "$out"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then package-synxdb-ce "$@"; fi
