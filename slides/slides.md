# Slides v2 — Build Once, Run on Any Linux (CoC Asia 2026)

> **Deck source (md-first).** Render into the **official CoC Asia template (mandatory)** — [Google Slides template](https://docs.google.com/presentation/d/1cAZfwR5Rs8pq6SCkguT-imlSpPVMKNpng1nJnjJe0MU/edit?usp=sharing) · [guide](https://asia.communityovercode.org/guide/presentation_slides_template.html). Required: **16:9**; **30 min total = 23–27 min content + 3–5 min Q&A**; at minimum use the template's title slide. One `## Slide` per slide; `Notes:` = speaker notes; `Chart:` blocks describe a visual to build in Slides.
>
> All numbers are verified against the shipped public companion repo `Synx-Data-Labs/2026-cfp-coc-asia` (the artifact the live demo reproduces). The one figure to refresh day-of is the exact **vendored-lib count**, read off a fresh `make dist`.
>
> 25 slides ≈ 1 min each. Use the template's title + thank-you/feedback slides.

---

## Slide 1 — Title

**Build Once, Run on Any Linux**
*SynxDB CE — A Truly Portable Binary Distribution of Apache Cloudberry (Incubating)*

Xin "Shine" Zhang — Cofounder/CTO, Synx Data Labs · with Ed Espino — Cofounder/CEO
Community Over Code Asia 2026 · Incubator track

Notes: Use the official template's title slide. First mention is the full form **"Apache Cloudberry (Incubating)"** (ASF brand rule). One line on who: ex-Greenplum / PostgreSQL background, now driving SynxDB CE's release pipeline. Set expectation: this is a release-engineering talk with a live, reproducible artifact — every number on these slides comes from a public CI run you can re-run yourself.

---

## Slide 2 — What is Apache Cloudberry (Incubating)?

- A **Postgres-compatible, massively-parallel (MPP) analytical database** — Greenplum lineage, now an ASF incubating project.
- Fast-growing community; the engine is mature and battle-tested.
- **SynxDB CE** is our Community Edition build of it.

Notes: Keep this to 45 seconds — most of this room knows MPP/Postgres. The point to plant: the *engine* isn't the hard part here; *shipping it as something you can install* is. That's the whole talk.

---

## Slide 3 — The gap: a source tarball is not something you can run

- Like most ASF projects, official Apache Cloudberry releases are **source tarballs** — correct for ASF governance.
- But hobbyists, evaluators, and enterprise teams all expect an **installable binary** — `dnf install`, `apt install`, done.
- Closing that last mile — *without* fighting ASF governance — is what SynxDB CE does.

Notes: Frame as a **community** problem, not a Synx pitch. ASF ships source on purpose; we're not criticizing that. We're closing the gap between "here's the source" and "here's a thing that runs," and open-sourcing how.

---

## Slide 4 — The obvious approach is a trap

"Just build one package per distro."

- **glibc symbol versions** differ across distros
- **compiler ABIs** differ (libstdc++, GCC versions)
- **bundled library versions** drift (OpenSSL, Perl, Python, …)
- **RPM vs DEB** packaging, two ways

→ a dozen variants of the *same* release to build, test, and maintain.

Notes: This is the "why is this hard" slide — the packaging/CI audience will nod. The trap is seductive because each individual package is *small*. The cost isn't size; it's the support surface, forever. Tee up the next slide: it multiplies.

---

## Slide 5 — 📊 The matrix that explodes

Chart: a multiplying chain, each `×` making the row visibly longer.

```
  distros        × OS versions  × CE releases   × channel        × arch
  ────────────────────────────────────────────────────────────────────
  Rocky            8 / 9           2.0 / 2.1       nightly          x86_64
  Ubuntu           20 / 22 / 24    …               rc               arm64
  Debian           12              …               GA
  openSUSE         15.x
  Amazon Linux     2023
  Fedora           40
  ────────────────────────────────────────────────────────────────────
            6+         ×  ~10        ×    N         ×    3       ×   2     =  hundreds
```

For a startup, every cell is a build to produce, a CI lane to keep green, and a customer to support.

Notes: This is the v1 "give concrete examples" feedback realized. The honest tension: the per-distro package is *tiny*, but the permutation count grows without bound — distros × OS versions × CE releases × nightly/rc/GA × arch. A startup release-engineering team cannot keep that many lanes green. The rest of the talk collapses this matrix to **one** build.

---

## Slide 6 — The bet: build once, run anywhere glibc is recent enough

**One arm64 binary tree. glibc as the only external dependency. No per-distro rebuild.**

Five moves:

1. Bundle the entire toolchain
2. Pin a glibc ABI floor (Rocky 8 / glibc 2.28)
3. Make glibc the only runtime dependency
4. One tree → RPM **and** DEB
5. Portability as a CI gate

Notes: This is the thesis. The next slides are these five moves, one or two each. Tell them the structure so they can follow. Note we deliberately picked **one arch (arm64)** to keep the story honest and the demo reproducible — x86_64 is "what's next," not "done."

---

## Slide 7 — 📊 Move 1: bundle the entire toolchain

The **host OS contributes nothing** to the compile.

Chart: a 2-layer stack.

```
  coc-toolchain:gcc12   ← Rocky 8 + GCC 12.3.0 built from source → /usr/local/toolchain
        ↓
  coc-build:rocky8      ← + Cloudberry core build deps (dnf) + fpm
        ↓
  build · vendor · package
```

- GCC **12.3.0** compiled from source into `/usr/local/toolchain/` — not the distro's GCC.
- Every build sources the same toolchain; the host compiler is never used.
- Same bits on every laptop and every CI runner.

Notes: v1 had four layers (incl. devel-cbcc, runtime) — Shine's feedback was to drop them. The public repo is **two** clean layers, so the diagram is simpler and truer. The point: reproducibility. The host is removed from the equation, so "works on my machine" cannot happen — the machine isn't in the build.

---

## Slide 8 — Move 1b: statically link the C++ runtime

```
LDFLAGS = -static-libstdc++ -static-libgcc
```

- Our from-source GCC has a **newer `libstdc++.so.6` / `libgcc_s.so.1`** than any target distro ships.
- Link them **statically** into the binary — otherwise a clean target can't find them.
- glibc stays dynamic (that's the one thing we *rely* on the host for).

Notes: This is a subtle one the packaging crowd will appreciate. If you bundle a modern toolchain you inherit a modern C++ runtime — and that runtime is *not* on the target. Static-linking libstdc++/libgcc is the clean fix and keeps the dependency surface down to exactly glibc. Sets up Move 3.

---

## Slide 9 — Move 2: a glibc 2.28 ABI floor (Rocky 8)

Build on **Rocky Linux 8** (glibc **2.28**). glibc's backward-compatibility guarantee does the rest.

- A binary linked against 2.28 runs **unchanged** on any distro with glibc ≥ 2.28.
- Target the *oldest* glibc you care about → everything newer is free.

Notes: The key insight non-packaging folks miss: glibc is **backward**-compatible (a 2.28 binary runs on 2.39), not forward. So you target the floor, not the ceiling. v1 floored at CentOS 7 / glibc 2.17 — Shine's call was "CentOS 7 is old, build on Rocky 8." We did, and verified it. Rocky 8 (2.28, ~2018) is a sane modern floor that still reaches a decade of distros.

---

## Slide 10 — 📊 The glibc backward-compatibility ladder

One arm64 build (floored at 2.28) — **CI-verified on 9 distros**:

| Distro | glibc | install |
|---|---|---|
| Rocky Linux 8 *(floor)* | 2.28 | dnf |
| openSUSE Leap 15.5 | 2.31 | zypper |
| Ubuntu 20.04 | 2.31 | apt |
| Amazon Linux 2023 | 2.34 | dnf |
| Rocky Linux 9 | 2.34 | dnf |
| Ubuntu 22.04 | 2.35 | apt |
| Debian 12 | 2.36 | apt |
| Ubuntu 24.04 | 2.39 | apt |
| Fedora 40 | 2.39 | dnf |

**glibc 2.28 → 2.39 — ~6 years of releases, one binary.**

Notes: This is the signature slide — build it as a ladder/number-line from 2.28 to 2.39 with the distros as rungs. The story in one image: pick the floor, get the rest for free. ~6 years (2.28 ≈ 2018 → 2.39 ≈ 2024). Don't overclaim the span — six years is plenty and it's true. Three package managers (dnf/apt/zypper), one binary.

---

## Slide 11 — Move 3: glibc is the *only* runtime dependency

Everything that isn't glibc is **vendored into `lib/`** and linked via an `$ORIGIN` rpath:

- OpenSSL, Xerces-C, OpenLDAP, krb5, APR, libevent, readline, zlib, libxml2/libxslt, libcurl, libuuid, bzip2, Perl, Python, PAM, libzstd, …

> No external package-manager dependencies. No *"install these 40 packages first."*

Notes: Show this as the contrast to Slide 4. The usual experience is resolving a dependency tree on the target host; here the only thing we ask of your machine is a glibc from the last several years. (The exact vendored-lib count is printed by `vendor.sh` on each build — read the live number off a fresh `make dist` before the talk rather than hard-coding it here.)

---

## Slide 12 — 📊 Move 3b: how the binary finds its own libraries

`$ORIGIN` rpath, computed **per ELF file** with `patchelf`:

```
  bin/postgres                     rpath → $ORIGIN/../lib
  lib/postgresql/.../some.so       rpath → $ORIGIN/../../..   (relative to ITS depth)
  ...
            ldd  →  every dependency resolves inside the package
```

- The package is **relocatable** — install it anywhere, no `LD_LIBRARY_PATH` needed for the server.
- glibc is the lone "not found here, ask the OS" line.

Notes: `$ORIGIN` means "relative to the ELF being loaded," so a deeply-nested `.so` needs a different number of `../` than a top-level binary — that's why rpath is computed per-file, not set globally. This is what makes the package relocatable and self-contained. It also sets up war-story #2 (the `LD_LIBRARY_PATH` leak) later.

---

## Slide 13 — Move 4: one tree → RPM **and** DEB

- Single build tree (`/usr/local/synxdb-ce`) → **both** artifacts via `fpm`, in the **same container**.
- No parallel pipelines, no second source of truth.
- **~39 MB** per package — the whole compiler-built, fully-vendored core.

Notes: Quick slide, but land the cool fact: the entire thing — Cloudberry core, a from-source GCC's output, every dependency vendored — is a **39 MB** package. People expect "fully bundled" to mean "gigabytes." It doesn't. The candid cost of `fpm` lands two slides later ("one tool does it, but it had teeth").

---

## Slide 14 — Move 5: portability as a CI gate

We don't *hope* it's portable — we **enforce** it on every commit:

- **`ldd` scan** on every binary in `bin/` and `lib/` → fail if anything is "not found" beyond glibc.
- **`postgres --version`** on a clean install of each target distro.
- Run across **all 9 distros**, fail-fast **off** (one flaky lane can't mask the rest).

Notes: This is what makes the claim credible instead of aspirational. The `ldd` gate is the cheapest, highest-signal test we have — it catches rpath mistakes, missing vendored libs, and stray glibc-symbol creep all at once. A green matrix is the proof. Mention the future symbol-level gate (`objdump -T | grep GLIBC_`) is on the roadmap (Slide 21).

---

## Slide 15 — 📊 The CI fan-out: prove it two ways

Chart: a fan-out diagram.

```
            build (arm64)
                 │
     ┌───────────┼───────────────────────────┐
     ▼           ▼            (×9 distros)     ▼
  smoke        smoke   ...   smoke          cluster
  (ldd +      (ldd +        (ldd +        (real MPP cluster,
  version)    version)      version)       query it)
     └───────────┴───────────────┬──────────┘
                                  ▼
                              release (on tag)
```

**11 jobs per commit**: 1 build + 9 portability lanes + 1 cluster.

Notes: Two kinds of proof on every commit. The 9 smoke lanes prove *portability* (it loads and runs everywhere). The cluster job proves *it actually works* (a real MPP cluster comes up and answers a query). Release only fires on a tag. This is the slide that says "this isn't a demo I rigged — it's CI."

---

## Slide 16 — The live demo: a real MPP cluster from the portable binary

`make cluster` →

- **1 coordinator + 1 standby + 2 primaries + 2 mirrors** via Cloudberry's `gpdemo`
- then `SELECT * FROM gp_segment_configuration;` — all segments up.

Notes: Live demo or recorded fallback. Run `make cluster` on one of the target distros (NOT Rocky 8 — show it on Ubuntu 24.04 or Fedora 40 to prove portability live). The payoff image: a multi-segment MPP topology, all `status = u`, built from a 39 MB package that the host's package manager installed with zero extra dependencies. Have a recorded version ready — never demo live without a backup.

---

## Slide 17 — The road not taken: why not just ship a container?

| | Container image | Portable package |
|---|---|---|
| Bare-metal / on-prem | needs a runtime + privileges | native install |
| Kernel / cgroup config | inherits host complexity | none |
| Size | still large (full userland) | ~39 MB |
| Ops familiarity | "another thing to run" | `dnf`/`apt` they know |

We chose the **package**.

Notes: This is Shine's "containers vs package" feedback. Be fair to containers — they're great for many shops. But many of our users are **bare-metal / on-prem** where Docker isn't welcome (privileges, kernel config, security posture), and even a container still ships a whole userland — it doesn't make the dependency problem go away, it relocates it. A relocatable native package meets those users where they are.

---

## Slide 18 — What didn't work #1: the RPM build-id collision

Vendored libs are **byte-identical copies** of the build floor's system libs → their GNU build-ids **collide** with the base packages that own those paths.

```
  → RPM refuses to install: conflicts with pcre2, libselinux, …
  fix:  fpm --rpm-rpmbuild-define '_build_id_links none'
  (DEB has no equivalent footgun.)
```

Notes: First of three honest stories — CoC audiences reward candor over a sales gloss. rpmbuild emits `/usr/lib/.build-id/*` symlinks keyed on each ELF's build-id. Because we vendored copies of the floor's own system libraries, those build-ids matched the base OS packages, and the RPM wouldn't co-exist with them. One fpm define fixes it; DEB never had the problem. The lesson: "fully bundled" collides with the host in ways you don't expect.

---

## Slide 19 — What didn't work #2: the vendored lib that broke `su`

Vendored `libselinux` (built on the Rocky 8 floor) + a leaked `LD_LIBRARY_PATH` →

```
  host tools (su, ssh, coreutils) load OUR libselinux
  → "no version information available"
  → PAM: "su: cannot open session: Module is unknown"
```

Fix: never leak `LD_LIBRARY_PATH` into host shell-outs; the `$ORIGIN` rpath means the *server* never needed it anyway.

Notes: The sharpest story. Our env script exported `LD_LIBRARY_PATH=$GPHOME/lib` for convenience; that leaked into any host command a shell spawned, so the OS's own `su`/`ssh` picked up *our* `libselinux` and PAM fell over. The irony: the `$ORIGIN` rpath (Slide 12) means the server binaries never needed `LD_LIBRARY_PATH` in the first place. Lesson: a relocatable package should keep its libs to *itself* — leaking them onto the host is its own footgun. (This is the proper-fix follow-up we have tracked.)

---

## Slide 20 — What didn't work #3: the smaller cuts

- **Standalone `postgres` won't start** in a bare smoke test — Cloudberry needs MPP/dbid context. So portability smoke = `ldd` + `--version`; *functional* proof is the cluster job.
- **`initdb` ENOSYS, intermittently**, only in some sandboxed CI runners — doesn't reproduce locally. Marked best-effort, non-fatal; under investigation.

Notes: Keep this brisk — two smaller honesty beats. The first shaped our test design (you can't just "run the server" to test an MPP binary). The second is the kind of CI-runner gremlin everyone in this room has fought — name it, say it's non-fatal and tracked, move on. Don't pretend CI is clean; they'll trust you more.

---

## Slide 21 — What's next

- **Verified *more* platforms** — x86_64, and a real SUSE install-and-smoke lane (not just "by glibc version").
- **Symbol-level ABI gate** — `objdump -T | grep GLIBC_` in CI, not just `ldd`.
- **Supply chain** — SBOM (SPDX/CycloneDX), GPG-signed RPM/DEB, SLSA provenance.
- **Build-time license scanning** + bundled NOTICE/LICENSE attribution.

Notes: This frames where it's heading and invites contribution — it's an open repo. "Verified more platforms" is Shine's reframing of the old "Verified SUSE" line: the principle is the same (don't claim a platform you don't CI), applied to x86_64 + SUSE. The supply-chain items signal maturity to the enterprise part of the room without being the focus.

---

## Slide 22 — Takeaways

1. **Build once, run anywhere on Linux** — a glibc floor + a fully bundled toolchain beats a per-distro matrix.
2. A **2-layer Docker toolchain** removes the host OS from the build.
3. Make **glibc the only runtime dependency** — vendor the rest with an `$ORIGIN` rpath.
4. **One tree → RPM + DEB**, and **enforce portability in CI** so the claim stays true.

**Cool facts:** ~39 MB package · 9 distros, glibc 2.28→2.39 · 11 CI jobs/commit · ~430 lines of build orchestration · fully open-source.

Notes: The memory card. If they remember one thing, it's #1. Read the cool-facts line slowly — those numbers are the proof the thesis is practical, not just elegant. Repeat the thesis once more.

---

## Slide 23 — Try it / contribute

- **`github.com/Synx-Data-Labs/2026-cfp-coc-asia`** — Apache-2.0, the whole pipeline.
- `make dist` builds it · `make smoke` runs the 9-distro gate · `make cluster` stands up the demo — on your laptop (Apple Silicon).
- Contribute upstream to **Apache Cloudberry (Incubating)** · try **SynxDB CE**.

Notes: Make it concrete and low-friction — everything on the prior slides is one `make` target away in a public repo. Invite two kinds of contribution: to the portable-build pipeline (this repo) and upstream to Cloudberry itself. Put the repo URL/QR on screen.

---

## Slide 24 — Apache Incubator disclaimer

> Apache Cloudberry is an effort undergoing incubation at The Apache Software Foundation (ASF), sponsored by the Apache Incubator. Incubation is required of all newly accepted projects until a further review indicates that the infrastructure, communications, and decision-making process have stabilized in a manner consistent with other successful ASF projects.

Notes: Required for incubating-project talks. Check the official CoC Google Slides template — it may already carry this; if so, don't duplicate. Confirm the canonical current wording on the Cloudberry site before the talk.

---

## Slide 25 — Thank you / Q&A

- Try SynxDB CE · contribute upstream to Apache Cloudberry (Incubating)
- Repo: `github.com/Synx-Data-Labs/2026-cfp-coc-asia` · contact / links
- Questions?

Notes: Use the template's thank-you/feedback slide (it may include a session-feedback QR). Leave 5 minutes. Backup slides for likely Q&A: "why Rocky 8, not a newer or older floor?", "static vs dynamic linking trade-offs?", "how big is the binary, really?", "licenses of the bundled libs?", "when x86_64?", "how do you handle CVEs in vendored libs?".
