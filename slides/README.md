`slides.md` is the md-first source for the Community over Code Asia talk deck.
Render it into the [official CoC Asia template](https://docs.google.com/presentation/d/1cAZfwR5Rs8pq6SCkguT-imlSpPVMKNpng1nJnjJe0MU/edit?usp=sharing) ([guide](https://asia.communityovercode.org/guide/presentation_slides_template.html)) — 16:9, 30 min total (23–27 min content + 3–5 min Q&A).

Two numbers are intentionally left dynamic — re-verify against a fresh run of this repo shortly before the talk:

- Slide 11's vendored-lib count (`vendor.sh`'s live output from a fresh `make dist`) — 51 as of the 2026-08-04 CI build
- The closing slide's Apache Incubator disclaimer wording (confirm current text on the Cloudberry site)

## Q&A prep (3–5 min)

Backup answers for the questions Slide 25's notes flag as likely, plus a few more the deck's claims invite. Answers are pinned to what's actually CI-verified in the public repo — don't overclaim past this.

**Why Rocky 8 / glibc 2.28 as the floor, not older or newer?**
v1 floored at CentOS 7 / glibc 2.17; Shine's call was that CentOS 7 is too old to build on today. Rocky 8 (2.28, ~2018) is a modern-enough floor that still reaches back ~6 years (2.28 → 2.39, Slide 10) across all 9 CI-verified distros. glibc is backward-compatible, so picking an older floor only helps if you have a target distro that old — we don't, so we didn't pay for it.

**Static vs. dynamic linking — why static-link libstdc++/libgcc but not glibc?**
The from-source GCC 12 toolchain ships a newer `libstdc++.so.6`/`libgcc_s.so.1` than any target distro has, so those two are statically linked in (Slide 8). glibc is the one thing left dynamic, on purpose — it's the ABI that's stable and backward-compatible across distros; statically linking glibc would lose that portability guarantee (and glibc's own static-linking story is famously unsupported for things like NSS/DNS resolution).

**How big is the binary, really?**
~39 MB per package (RPM and DEB), for the whole thing — Cloudberry core, the from-source GCC's output, and every vendored dependency (Slide 13).

**How many dependencies does it actually pull in?**
51 non-glibc shared libraries get vendored into `lib/` (OpenSSL, Xerces-C, OpenLDAP, krb5, libcurl, libxml2, Perl, Python, PAM, libzstd, …) and rpath'd via `$ORIGIN` (Slides 11–12). glibc itself is the only thing resolved from the host.

**What about licenses of the bundled libraries?**
Not yet automated — build-time license scanning + bundled NOTICE/LICENSE attribution is on the roadmap (Slide 21), not shipped today. If pressed: today it's a manual audit, not a CI gate.

**How do you handle CVEs in vendored libs?**
Also not yet a dedicated pipeline — this is exactly why "supply chain" (SBOM, signed packages, SLSA provenance) is called out as what's next (Slide 21), not what's done. Honest answer: a CVE in a vendored lib today means rebuilding and re-vendoring, same as any vendored-dependency model; there's no automated CVE scan gate yet.

**When does x86_64 land?**
No committed date — it's explicitly "what's next," not "done" (Slide 6, Slide 21). The whole story here was kept to one arch (arm64) deliberately, to keep the CI matrix and the live demo honest and reproducible.

**Why not just ship a container?**
Slide 17's table: many users are bare-metal/on-prem where a container runtime isn't welcome (privileges, kernel/cgroup config, security posture), and a container still ships a full userland — it relocates the dependency problem rather than removing it. A relocatable native package meets those users where `dnf`/`apt` already work.

**Is this really tested, or just claimed?**
It's a CI gate on every commit, not a one-off claim (Slide 14–15): an `ldd` scan + `postgres --version` across all 9 distros, plus a real cluster-bring-up job — 11 jobs per commit. All of it is public and re-runnable (`Synx-Data-Labs/2026-cfp-coc-asia`).

**Does this affect the upstream Apache Cloudberry (Incubating) project?**
No — this is SynxDB CE's packaging/release-engineering layer on top of the upstream source release. Cloudberry is still incubating at the ASF; nothing here changes that governance, and the disclaimer on the closing slide is required precisely because of that status.
