# 2026-cfp-coc-asia — Build Once, Run on Any Linux

Companion repo for the Community Over Code Asia 2026 talk *"Build Once, Run on Any
Linux: A Truly Portable Binary Distribution for Apache Cloudberry (Incubating)"*.

It builds the **core** of [Apache Cloudberry (Incubating)](https://cloudberry.apache.org/)
from the public upstream source into a portable **arm64** Linux binary (RPM + DEB) —
built on a Rocky 8 / glibc-2.28 floor with a from-source GCC toolchain, every non-glibc
library vendored in, so one build runs on every current arm64 Linux distro (glibc ≥ 2.28).
This is a **build of**, not a fork of, Apache Cloudberry.

> Apache Cloudberry is an effort undergoing incubation at The Apache Software Foundation
> (ASF), sponsored by the Apache Incubator.

> **🚧 Status (June 2026): early but working.** From-source GCC toolchain, Apache Cloudberry
> **core** compile, static-linked C++ runtime, and **dependency vendoring** are all in place:
> every non-glibc library (OpenSSL, Xerces, LDAP, krb5, …) is bundled into `lib/` with an
> `$ORIGIN` rpath, so **glibc is the only runtime dependency**. CI builds once and verifies the
> binary **loads + runs** (`postgres --version`) across Rocky 8/9, Ubuntu 22.04/24.04, and Debian 12.
> `initdb` + `SELECT version()` succeed in normal runs; the CI **functional smoke is best-effort** —
> an intermittent `cdb_init.d` `ENOSYS` in some sandboxed runners (does not reproduce locally) is
> still under investigation, so it never fails the build.

## Reproduce on Apple Silicon

```bash
docker build --platform=linux/arm64 -t coc-toolchain:gcc12 toolchain/   # GCC from source (slow, once)
docker build --platform=linux/arm64 -t coc-build:rocky8 .
docker run --rm --platform=linux/arm64 -v "$PWD":/work coc-build:rocky8 \
  bash -lc 'bash /opt/build.sh && bash /opt/vendor.sh && bash /work/package.sh'  # build → vendor → dist/*.rpm,*.deb
docker run --rm --platform=linux/arm64 -v "$PWD":/work ubuntu:24.04 \
  bash -lc 'dpkg -i /work/dist/synxdb-ce_*_arm64.deb; bash /work/test.sh'        # portability gate + smoke
```

## What's here
| Path | What |
|---|---|
| `toolchain/` | GCC 12 from-source build image |
| `Dockerfile` | build environment (Cloudberry core deps) |
| `build.sh` · `vendor.sh` · `package.sh` · `test.sh` | build · vendor non-glibc deps (`$ORIGIN` rpath) · package (fpm) · portability gate + smoke |
| `.github/workflows/build.yml` | arm64 CI: build → vendor → multi-distro smoke → Releases |
| `slides/` | the talk |

## License
Apache-2.0 (this repo) — builds Apache Cloudberry (Incubating), also Apache-2.0. See `NOTICE`.
