# 2026-cfp-coc-asia — Build Once, Run on Any Linux

Companion repo for the [Community Over Code Asia 2026 talk](https://sessionize.com/s/shine-zhang/build-once-run-on-any-linux-synxdb-ce-for-apache-c/177992) *"Build Once, Run on Any
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
> `$ORIGIN` rpath, so **glibc is the only runtime dependency**. CI builds once and proves it two ways:
> a **portability matrix** that loads + runs the binary (`postgres --version`) on nine arm64 distros
> (glibc ≥ 2.28), and a **cluster job** that stands up a real MPP cluster (coordinator + standby +
> 2 primaries + 2 mirrors) and queries it. `make cluster` does the same on your laptop.

## Reproduce on Apple Silicon

Everything is wrapped in a `Makefile` — run `make` to list targets:

```bash
make dist       # build GCC + Cloudberry core, vendor deps, package -> dist/*.rpm,*.deb  (slow, once)
make test       # install the package into a clean distro + portability gate (TARGET=ubuntu:24.04)
make smoke      # the portability gate across all 9 distros
make cluster    # coordinator + standby + 2 primaries + 2 mirrors, then print gp_segment_configuration
```

Already have a local `apache/cloudberry` checkout? `make dist CLOUDBERRY_LOCAL_SRC=/path/to/it`
clones from it instead of the remote (still a fresh clone each time — no network access to
`github.com` for the Cloudberry source).

<details><summary>…or without make (raw docker)</summary>

```bash
docker build --platform=linux/arm64 -t coc-toolchain:gcc12 toolchain/   # GCC from source (slow, once)
docker build --platform=linux/arm64 -t coc-build:rocky8 .
docker run --rm --platform=linux/arm64 -v "$PWD":/work coc-build:rocky8 \
  bash -lc 'bash /opt/build.sh && bash /opt/vendor.sh && bash /work/package.sh'  # -> dist/*.rpm,*.deb
docker run --rm --platform=linux/arm64 -v "$PWD":/work ubuntu:24.04 \
  bash -lc 'apt-get install -y /work/dist/synxdb-ce_*_arm64.deb; bash /work/test.sh'
```

</details>

## What's here
| Path | What |
|---|---|
| `Makefile` | laptop entrypoint — `make help` lists targets |
| `toolchain/` | GCC 12 from-source build image |
| `Dockerfile` | build environment (Cloudberry core deps) |
| `build.sh` · `vendor.sh` · `package.sh` | build · vendor non-glibc deps (`$ORIGIN` rpath) · package (fpm RPM+DEB) |
| `test.sh` | portability gate (`ldd` + `postgres --version`) on a clean distro |
| `cluster.sh` | provision a single-host MPP demo cluster via `gpdemo` + print `gp_segment_configuration` |
| `.github/workflows/build.yml` | arm64 CI: build → 9-distro portability matrix + MPP cluster job → Releases |
| `slides/` | the talk |

## Runs on (glibc ≥ 2.28)
One arm64 build, verified in CI on:

| Distro | glibc | install |
|---|---|---|
| Rocky Linux 8 (floor) | 2.28 | dnf |
| Rocky Linux 9 | 2.34 | dnf |
| Ubuntu 20.04 / 22.04 / 24.04 | 2.31 / 2.35 / 2.39 | apt |
| Debian 12 | 2.36 | apt |
| openSUSE Leap 15.5 | 2.31 | zypper |
| Amazon Linux 2023 | 2.34 | dnf |
| Fedora 40 | 2.39 | dnf |

## Cluster demo

`make cluster` (or `bash cluster.sh` inside a target container) brings up a single-host MPP
cluster — **1 coordinator + 1 standby + 2 primaries + 2 mirrors** — with Cloudberry's `gpdemo`,
then prints the topology:

```
 dbid | content | role | mode | status | port |              datadir
    1 |      -1 | p    | n    | u      | 7000 | .../qddir/demoDataDir-1
    6 |      -1 | m    | s    | u      | 7001 | .../standby
    2 |       0 | p    | s    | u      | 7002 | .../dbfast1/demoDataDir0
    4 |       0 | m    | s    | u      | 7004 | .../dbfast_mirror1/demoDataDir0
    3 |       1 | p    | s    | u      | 7003 | .../dbfast2/demoDataDir1
    5 |       1 | m    | s    | u      | 7005 | .../dbfast_mirror2/demoDataDir1
```

The server binary stays glibc-only; the management utilities' Python deps (PyGreSQL, psutil,
PyYAML) are installed at provision time against the target's `python3`.

## License
Apache-2.0 (this repo) — builds Apache Cloudberry (Incubating), also Apache-2.0. See `NOTICE`.
