#!/usr/bin/env bash
# Clone Apache Cloudberry (Incubating) at a pinned tag and build the CORE database.
# CLOUDBERRY_LOCAL_SRC (optional): clone from this local path instead of the
# remote -- a fresh clone either way, so the tree stays clean regardless of
# source. A ref that isn't reachable from the local source fails loudly
# (git clone's own error) rather than silently falling back to the remote.
set -euo pipefail

build-cloudberry() {
  local ref="${CLOUDBERRY_REF:-2.1.0-incubating}"   # pinned public Apache tag
  local src="/tmp/cloudberry" prefix="/usr/local/synxdb-ce"
  source /etc/profile.d/toolchain.sh

  rm -rf "$src"
  if [ -n "${CLOUDBERRY_LOCAL_SRC:-}" ]; then
    [ -d "$CLOUDBERRY_LOCAL_SRC" ] || { echo "build.sh: CLOUDBERRY_LOCAL_SRC=$CLOUDBERRY_LOCAL_SRC not found" >&2; return 1; }
    git clone --branch "$ref" "$CLOUDBERRY_LOCAL_SRC" "$src"   # --depth is a no-op for local clones (git warns and ignores it)
  else
    git clone --depth 1 --branch "$ref" https://github.com/apache/cloudberry.git "$src"
  fi
  cd "$src"
  # Static-link the C++ runtime: otherwise the binary needs the custom GCC's
  # libstdc++.so.6 / libgcc_s.so.1 at runtime — not present on a clean target.
  ./configure --prefix="$prefix" \
    --enable-orca --with-perl --with-python --with-openssl --with-libxml \
    --with-libxslt --with-gssapi --with-ldap --with-pam --with-uuid=e2fs \
    LDFLAGS="-static-libstdc++ -static-libgcc"
  # MAKE_JOBS caps parallelism — ORCA's -O3 C++ TUs are RAM-heavy, and CI
  # (hosted runner, ~16 GB shared) OOMs at -j$(nproc); local builds keep full width.
  make -j"${MAKE_JOBS:-$(nproc)}"
  make install
  echo "built Cloudberry core $ref → $prefix"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then build-cloudberry "$@"; fi
