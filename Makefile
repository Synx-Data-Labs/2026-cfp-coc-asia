# Makefile — laptop-friendly wrapper around the build / test / cluster scripts.
# Pure orchestration: every recipe is a `docker build` or `docker run ... <existing .sh>`,
# so the *.sh files stay the single source of truth. Run `make` (or `make help`) to list targets.
#
# Typical flow on an Apple-Silicon laptop:
#   make dist          # build + vendor + package -> dist/*.rpm,*.deb  (slow: builds GCC + Cloudberry)
#   make test          # install dist/ pkg into one distro + portability gate
#   make smoke         # the same across the full distro matrix
#   make cluster       # stand up a 1+1+2+2 MPP demo cluster + show gp_segment_configuration
# (test / smoke / cluster install from dist/, so run `make dist` first — or drop release artifacts in dist/.)

PLATFORM        ?= linux/arm64
TOOLCHAIN_IMAGE ?= coc-toolchain:gcc12
BUILD_IMAGE     ?= coc-build:rocky8
GCC_VERSION     ?= 12.3.0
CLOUDBERRY_REF  ?= 2.1.0-incubating
CLOUDBERRY_LOCAL_SRC ?=                    # optional: path to an existing local apache/cloudberry checkout
                                            # (at CLOUDBERRY_REF) -- clone from it instead of the remote
MAKE_JOBS       ?= 2                       # ORCA's -O3 is RAM-heavy; raise on a big box: make dist MAKE_JOBS=8
PKG_VERSION     ?= 2.1.0
TARGET          ?= ubuntu:24.04            # single distro for `make test`
CLUSTER_IMAGE   ?= rockylinux:9            # distro for `make cluster`
SMOKE_DISTROS   ?= rockylinux:8 rockylinux:9 ubuntu:20.04 ubuntu:22.04 ubuntu:24.04 debian:12 opensuse/leap:15.5 amazonlinux:2023 fedora:40

DOCKER_RUN = docker run --rm --platform=$(PLATFORM) -v "$(CURDIR)":/work -w /work
# Install the built package with whichever package manager the distro ships (deb -> apt, SUSE -> zypper, else dnf).
INSTALL = (command -v apt-get >/dev/null && apt-get update -qq && apt-get install -y /work/dist/synxdb-ce_*_arm64.deb) || (command -v zypper >/dev/null && zypper --no-gpg-checks --non-interactive install -y /work/dist/synxdb-ce-*.aarch64.rpm) || (command -v dnf >/dev/null && dnf -y install /work/dist/synxdb-ce-*.aarch64.rpm)

.DEFAULT_GOAL := help
.PHONY: help toolchain image dist test smoke cluster clean

help:  ## List targets
	@awk 'BEGIN{FS=":.*##"} /^[a-zA-Z0-9_\/-]+:.*##/{printf "  \033[36m%-9s\033[0m %s\n",$$1,$$2}' $(MAKEFILE_LIST)

toolchain:  ## Build the from-source GCC 12 base image (slow, once)
	docker build --platform=$(PLATFORM) --build-arg GCC_VERSION=$(GCC_VERSION) -t $(TOOLCHAIN_IMAGE) toolchain/

image: toolchain  ## Build the Rocky 8 build/runtime image
	docker build --platform=$(PLATFORM) -t $(BUILD_IMAGE) .

dist: image  ## Build + vendor + package -> dist/*.rpm,*.deb (one container). CLOUDBERRY_LOCAL_SRC=... to clone from a local checkout instead of the remote.
	@if find dist -maxdepth 1 \( -name '*.rpm' -o -name '*.deb' \) 2>/dev/null | grep -q .; then \
	  echo "error: dist/ already has package artifacts — run 'make clean dist' to rebuild from scratch." >&2; \
	  exit 1; \
	fi
	$(DOCKER_RUN) $(if $(CLOUDBERRY_LOCAL_SRC),-v "$(CLOUDBERRY_LOCAL_SRC)":/mnt/cloudberry-src:ro -e CLOUDBERRY_LOCAL_SRC=/mnt/cloudberry-src,) \
	  -e MAKE_JOBS=$(MAKE_JOBS) -e CLOUDBERRY_REF=$(CLOUDBERRY_REF) -e PKG_VERSION=$(PKG_VERSION) $(BUILD_IMAGE) \
	  bash -lc 'bash /opt/build.sh && bash /opt/vendor.sh && bash /work/package.sh'

test:  ## Install dist/ package into one distro (TARGET=...) + portability gate
	$(DOCKER_RUN) $(TARGET) bash -lc '$(INSTALL); bash /work/test.sh'

smoke:  ## Run the portability gate across the full distro matrix (SMOKE_DISTROS=...)
	@for img in $(SMOKE_DISTROS); do \
	  echo "==================== smoke: $$img ===================="; \
	  $(DOCKER_RUN) $$img bash -lc '$(INSTALL); bash /work/test.sh' || exit 1; \
	done

cluster:  ## Stand up the 1+1+2+2 MPP demo cluster (CLUSTER_IMAGE=...) + show gp_segment_configuration
	$(DOCKER_RUN) $(CLUSTER_IMAGE) bash -lc 'bash /work/cluster.sh'

clean:  ## Remove built artifacts (dist/)
	rm -rf dist
