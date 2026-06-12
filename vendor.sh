#!/usr/bin/env bash
# Vendor every non-glibc shared-library dependency into <prefix>/lib and rpath
# all ELF files to it, so the package's ONLY external runtime dependency is glibc.
# Run inside the build image (needs ldd + patchelf + the system libs to copy).
set -uo pipefail

vendor-synxdb-ce() {
  local prefix="${1:-/usr/local/synxdb-ce}"
  local libdir="$prefix/lib"
  mkdir -p "$libdir"
  unset LD_LIBRARY_PATH   # resolve deps against the base system, not the build toolchain (deterministic)

  # Libraries every glibc >= 2.28 target already ships — never bundle these
  # (bundling libc et al. would break the binary). Everything else is vendored.
  local keep='^(libc|libm|libpthread|libdl|librt|libresolv|libutil|libnsl|libanl|libBrokenLocale|ld-linux-aarch64|ld-linux)\.so'

  # Transitive closure: re-scan until no new lib is copied (libdir is scanned, so
  # each pass also resolves deps of libs copied in earlier passes). Cap at 10.
  local pass changed
  for pass in $(seq 1 10); do
    changed=0
    while IFS= read -r elf; do
      while read -r soname sopath; do
        [ -z "${sopath:-}" ] && continue
        case "$sopath" in /*) ;; *) continue ;; esac      # only real resolved paths
        echo "$soname" | grep -Eq "$keep" && continue       # skip glibc/loader
        [ -e "$libdir/$soname" ] && continue                # already vendored
        if cp -L "$sopath" "$libdir/$soname" 2>/dev/null; then
          echo "  pass $pass: vendored $soname"
          changed=1
        fi
      done < <(ldd "$elf" 2>/dev/null | awk '/=>/ {print $1, $3}')
    done < <(find "$prefix/bin" "$libdir" -type f 2>/dev/null)
    [ "$changed" = 0 ] && { echo "closure stable after pass $pass"; break; }
  done

  # rpath each ELF to point exactly at <prefix>/lib from its own location, computed
  # PER-FILE so deeply-nested binaries (e.g. lib/postgresql/pgxs/src/test/*, ~6 levels
  # down) still reach the bundle. $ORIGIN-relative only — no absolute paths.
  local n=0 f rel d depth up i
  while IFS= read -r f; do
    patchelf --print-rpath "$f" >/dev/null 2>&1 || continue   # ELF only
    rel="${f#"$prefix"/}"
    d="$(dirname "$rel")"
    depth="$(printf '%s\n' "$d" | tr '/' '\n' | grep -c .)"
    up=""; for ((i=0; i<depth; i++)); do up="$up/.."; done
    patchelf --set-rpath "\$ORIGIN${up}/lib" "$f" 2>/dev/null && n=$((n+1))
  done < <(find "$prefix/bin" "$libdir" -type f 2>/dev/null)

  echo "vendored $(find "$libdir" -maxdepth 1 -name '*.so*' | wc -l | tr -d ' ') libs; rpath set on $n ELF files"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then vendor-synxdb-ce "$@"; fi
