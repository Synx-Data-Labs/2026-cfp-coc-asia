#!/usr/bin/env bash
# Provision a single-host Apache Cloudberry (Incubating) DEMO cluster:
#   1 coordinator + 1 standby + 2 primaries + 2 mirrors, via gpdemo.
# Run inside a target-distro container (the CE package is installed from /work/dist
# if not already present). The MPP management utilities (gpdemo -> gpstart/gpstate)
# need a few Python deps that are NOT in the package; we install them at provision
# time, compiled against the TARGET's python (bundling a compiled PyGreSQL would tie
# the package to one python version). The server binary itself stays glibc-only.
#
# Not a production topology: primaries and their mirrors are co-located on one host.
set -euo pipefail

PREFIX="${PREFIX:-/usr/local/synxdb-ce}"
GPUSER="${GPUSER:-gpadmin}"
DATADIR="${DATADIR:-/home/$GPUSER/gpdemo-data}"
PRIMARIES="${PRIMARIES:-2}"                 # => PRIMARIES primaries + PRIMARIES mirrors
NOISE='no version information available'    # cosmetic: vendored libselinux shadows the OS copy (follow-up: rpath it)

_detect_pkg_mgr() {
  command -v dnf    >/dev/null 2>&1 && { echo dnf;    return; }
  command -v zypper >/dev/null 2>&1 && { echo zypper; return; }
  command -v apt-get>/dev/null 2>&1 && { echo apt;    return; }
  echo "cluster.sh: no supported package manager (dnf/zypper/apt)" >&2; return 1
}

_ensure_ce() {   # install the CE package from /work/dist if gpdemo isn't present yet
  [ -x "$PREFIX/bin/gpdemo" ] && return 0
  ls /work/dist/synxdb-ce* >/dev/null 2>&1 \
    || { echo "cluster.sh: no package in /work/dist — run 'make dist' or stage release artifacts first" >&2; return 1; }
  echo "== installing the CE package from /work/dist =="
  case "$1" in
    dnf)    dnf -y install /work/dist/synxdb-ce-*.aarch64.rpm ;;
    zypper) zypper --no-gpg-checks --non-interactive install -y /work/dist/synxdb-ce-*.aarch64.rpm ;;
    apt)    apt-get update -qq && apt-get install -y /work/dist/synxdb-ce_*_arm64.deb ;;
  esac
}

_install_host_deps() {   # tools gpinitsystem/gpstart need + python build deps + sshd. Idempotent.
  echo "== installing host + python management deps (provision-time, not in the package) =="
  case "$1" in
    dnf)    dnf -y install python3-pip python3-devel gcc which procps-ng hostname iproute \
              util-linux iputils openssh-server openssh-clients shadow-utils >/dev/null ;;
    zypper) zypper --non-interactive install -y python3-pip python3-devel gcc which procps \
              hostname iproute2 util-linux iputils openssh shadow >/dev/null ;;
    apt)    export DEBIAN_FRONTEND=noninteractive; apt-get update -qq; apt-get install -y \
              python3-pip python3-dev gcc debianutils procps hostname iproute2 util-linux iputils-ping \
              openssh-server openssh-client passwd >/dev/null ;;
  esac
}

_install_py_deps() {   # gppylib needs pgdb/pg (PyGreSQL, no arm64 wheel -> compiles), psutil, PyYAML
  # Subshell: confine cloudberry-env.sh's LD_LIBRARY_PATH so it does NOT leak into the host
  # useradd/su below — the vendored libselinux otherwise breaks PAM ("su: cannot open session:
  # Module is unknown"). gpadmin's own commands source the env inside their own `su -c`.
  # shellcheck disable=SC1090
  ( source "$PREFIX/cloudberry-env.sh"
    PATH="$PREFIX/bin:$PATH" LDFLAGS="-L$PREFIX/lib" \
      python3 -m pip install --no-input --disable-pip-version-check --retries 5 --timeout 60 psutil PyYAML PyGreSQL >/dev/null )
}

_setup_ssh() {   # gpdemo's gpinitstandby/gpstart ssh to the host by name even single-node
  ssh-keygen -A 2>/dev/null || true
  mkdir -p /run/sshd
  pgrep -x sshd >/dev/null 2>&1 || /usr/sbin/sshd
  id "$GPUSER" >/dev/null 2>&1 || useradd -m "$GPUSER"
  mkdir -p "$DATADIR"; chown -R "$GPUSER":"$GPUSER" "$DATADIR"
  su - "$GPUSER" -c '
    set -e
    mkdir -p ~/.ssh && chmod 700 ~/.ssh
    [ -f ~/.ssh/id_rsa ] || ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa -q
    grep -qxf ~/.ssh/id_rsa.pub ~/.ssh/authorized_keys 2>/dev/null || cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    printf "Host *\n  StrictHostKeyChecking no\n  UserKnownHostsFile /dev/null\n  LogLevel ERROR\n" > ~/.ssh/config
    chmod 600 ~/.ssh/config'
}

provision-demo-cluster() {
  local mgr; mgr="$(_detect_pkg_mgr)"
  _ensure_ce "$mgr"
  _install_host_deps "$mgr"
  _install_py_deps
  _setup_ssh

  echo "== bringing up demo cluster: coordinator + standby + $PRIMARIES primaries + $PRIMARIES mirrors =="
  # gpdemo is unattended (demo_cluster.sh calls gpinitsystem -a). WITH_MIRRORS=true
  # auto-enables the standby. Idempotent: tear down any prior cluster first.
  su - "$GPUSER" -c "source $PREFIX/cloudberry-env.sh; cd $DATADIR
    [ -f gpdemo-env.sh ] && NUM_PRIMARY_MIRROR_PAIRS=$PRIMARIES WITH_MIRRORS=true gpdemo -d >/dev/null 2>&1 || true
    rm -rf datadirs gpdemo-env.sh clusterConfigFile hostfile ./*.log 2>/dev/null || true
    NUM_PRIMARY_MIRROR_PAIRS=$PRIMARIES WITH_MIRRORS=true gpdemo"

  echo
  echo "== gpinitsystem config gpdemo generated =="
  su - "$GPUSER" -c "cat $DATADIR/clusterConfigFile" 2>/dev/null || true

  echo
  echo "== SELECT * FROM gp_segment_configuration =="
  su - "$GPUSER" -c "source $PREFIX/cloudberry-env.sh; source $DATADIR/gpdemo-env.sh
    psql -d postgres -c 'SELECT * FROM gp_segment_configuration ORDER BY content, role;'" 2>&1 | { grep -v "$NOISE" || true; }

  echo
  echo "== cluster health =="
  local q="source $PREFIX/cloudberry-env.sh; source $DATADIR/gpdemo-env.sh; psql -d postgres -tAc"
  local total down expected=$(( 2 * PRIMARIES + 2 ))   # coordinator + standby + N primaries + N mirrors
  total=$(su - "$GPUSER" -c "$q 'SELECT count(*) FROM gp_segment_configuration;'" 2>/dev/null | tr -dc 0-9 || true)
  down=$(su - "$GPUSER" -c "$q \"SELECT count(*) FROM gp_segment_configuration WHERE status<>'u';\"" 2>/dev/null | tr -dc 0-9 || true)
  if [ "${total:-0}" -eq "$expected" ] && [ "${down:-1}" -eq 0 ]; then
    echo "CLUSTER OK: $total segments (coordinator + standby + $PRIMARIES primaries + $PRIMARIES mirrors), all up"
  else
    echo "CLUSTER UNHEALTHY: total=${total:-?} (expected $expected) down=${down:-?}"; return 1
  fi
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then provision-demo-cluster "$@"; fi
