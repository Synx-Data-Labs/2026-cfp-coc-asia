#!/usr/bin/env bash
# Clone Apache Cloudberry (Incubating) at a pinned tag and build the CORE database.
set -euo pipefail

build-cloudberry() {
  local ref="${CLOUDBERRY_REF:-2.1.0-incubating}"   # pinned public Apache tag
  local src="/tmp/cloudberry" prefix="/usr/local/synxdb-ce"
  source /etc/profile.d/toolchain.sh

  rm -rf "$src"
  git clone --depth 1 --branch "$ref" https://github.com/apache/cloudberry.git "$src"
  cd "$src"
  # Static-link the C++ runtime: otherwise the binary needs the custom GCC's
  # libstdc++.so.6 / libgcc_s.so.1 at runtime — not present on a clean target.
  ./configure --prefix="$prefix" \
    --enable-orca --with-perl --with-python --with-openssl --with-libxml \
    --with-libxslt --with-gssapi --with-ldap --with-pam --with-uuid=e2fs \
    LDFLAGS="-static-libstdc++ -static-libgcc"
  make -j"$(nproc)"
  make install
  echo "built Cloudberry core $ref → $prefix"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then build-cloudberry "$@"; fi
