# 2026-cfp-coc-asia — Build Once, Run on Any Linux

Companion repo for the Community Over Code Asia 2026 talk *"Build Once, Run on Any
Linux: A Truly Portable Binary Distribution for Apache Cloudberry (Incubating)"*.

It builds the **core** of [Apache Cloudberry (Incubating)](https://cloudberry.apache.org/)
from the public upstream source into a portable **arm64** Linux binary (RPM + DEB) —
built on a Rocky 8 / glibc-2.28 floor with a from-source GCC toolchain, so one build
runs on every current arm64 Linux distro (glibc ≥ 2.28). This is a **build of**, not a
fork of, Apache Cloudberry.

> Apache Cloudberry is an effort undergoing incubation at The Apache Software Foundation
> (ASF), sponsored by the Apache Incubator.

## Reproduce on Apple Silicon

```bash
docker build --platform=linux/arm64 -t coc-toolchain:gcc12 toolchain/   # GCC from source (slow, once)
docker build --platform=linux/arm64 -t coc-build:rocky8 .
docker run --rm --platform=linux/arm64 -v "$PWD":/work coc-build:rocky8 \
  bash -lc 'bash /opt/build.sh && bash /work/package.sh'                  # → dist/*.rpm, *.deb
docker run --rm --platform=linux/arm64 -v "$PWD":/work ubuntu:24.04 \
  bash -lc 'dpkg -i /work/dist/synxdb-ce_*_arm64.deb; bash /work/test.sh' # portability + smoke
```

## What's here
| Path | What |
|---|---|
| `toolchain/` | GCC 12 from-source build image |
| `Dockerfile` | build environment (Cloudberry core deps) |
| `build.sh` · `package.sh` · `test.sh` | build · package (fpm) · portability gate + smoke |
| `.github/workflows/build.yml` | arm64 CI: build → multi-distro smoke → Releases |
| `slides/` | the talk |

## License
Apache-2.0 (this repo) — builds Apache Cloudberry (Incubating), also Apache-2.0. See `NOTICE`.
