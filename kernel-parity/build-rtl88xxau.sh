#!/usr/bin/env bash
# ShadowStrike OS - Kernel Parity Toolkit
# build-rtl88xxau.sh - EXPERIMENTAL, UNTESTED ROUTE. READ THIS FIRST.
#
# This script attempts something that, at the time of writing, has no public
# record of success or failure: building the out-of-tree Realtek RTL8812AU
# driver (the aircrack-ng rtl8812au tree) against the kernel headers that
# OrbStack itself ships inside its Linux machines, instead of against a
# distribution kernel that OrbStack is not running.
#
# It will refuse to run without an explicit acknowledgement flag.
# It does NOT load the module it builds. Loading is a manual step, printed
# at the end, for a human to decide on.
#
# Usage:
#   ./build-rtl88xxau.sh --i-understand-this-is-experimental
#   ./build-rtl88xxau.sh --i-understand-this-is-experimental --install-deps
#   ./build-rtl88xxau.sh --i-understand-this-is-experimental --local-src /path/to/rtl8812au
#
# Flags:
#   --i-understand-this-is-experimental   Required. Acknowledges the risk.
#   --install-deps                        Also install build dependencies
#                                         with apt. Without this flag the
#                                         script installs nothing.
#   --local-src DIR                       Use an existing driver checkout
#                                         instead of cloning at runtime.
#
# Exit status: 0 only when a .ko file was produced. Non-zero otherwise,
# with a FAILED-AT-<step> verdict printed and written to the log.

set -u

ACK="no"
INSTALL_DEPS="no"
LOCAL_SRC=""

while [ $# -gt 0 ]; do
    case "$1" in
        --i-understand-this-is-experimental)
            ACK="yes"
            shift
            ;;
        --install-deps)
            INSTALL_DEPS="yes"
            shift
            ;;
        --local-src)
            if [ $# -lt 2 ]; then
                echo "ERROR: --local-src needs a directory argument" >&2
                exit 2
            fi
            LOCAL_SRC="$2"
            shift 2
            ;;
        *)
            echo "ERROR: unknown argument: $1" >&2
            echo "Usage: $0 --i-understand-this-is-experimental [--install-deps] [--local-src DIR]" >&2
            exit 2
            ;;
    esac
done

echo "=============================================================="
echo " EXPERIMENTAL: RTL8812AU build against OrbStack shipped headers"
echo " This route is untested. The module, if built, is NOT loaded"
echo " by this script."
echo "=============================================================="

if [ "${ACK}" != "yes" ]; then
    echo
    echo "REFUSED: this script is experimental and changes nothing until you"
    echo "say so explicitly. Re-run with:"
    echo "  --i-understand-this-is-experimental"
    exit 2
fi

WORKDIR="$(mktemp -d /tmp/rtl88xxau-build.XXXXXX 2>/dev/null)" || {
    echo "FAILED-AT-setup: could not create a work directory in /tmp"
    exit 1
}
LOG_FILE="${WORKDIR}/build.log"
: > "${LOG_FILE}"

# From here on, everything is logged.
exec > >(tee -a "${LOG_FILE}") 2>&1

fail() {
    echo
    echo "VERDICT: FAILED-AT-$1"
    echo "Log: ${LOG_FILE}"
    echo "Work directory kept for inspection: ${WORKDIR}"
    exit 1
}

step() {
    echo
    echo "--- Step: $1 ---"
}

# ---------------------------------------------------------------------------
step "preflight"
# ---------------------------------------------------------------------------
KERNEL_RELEASE="$(uname -r)"
echo "Running kernel: ${KERNEL_RELEASE}"
echo "Architecture  : $(uname -m)"
echo "Work dir      : ${WORKDIR}"
echo "Log file      : ${LOG_FILE}"

for tool in make gcc tar xz git; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
        echo "Missing build tool: ${tool}"
        if [ "${INSTALL_DEPS}" != "yes" ]; then
            echo "Re-run with --install-deps to install build dependencies,"
            echo "or install them yourself: build-essential git xz-utils"
            fail "preflight-missing-${tool}"
        fi
    fi
done

if [ "${INSTALL_DEPS}" = "yes" ]; then
    step "install-deps"
    echo "Installing build dependencies with apt (this is the only"
    echo "system-wide change this script makes, and only with your flag)."
    if command -v sudo >/dev/null 2>&1; then SUDO="sudo"; else SUDO=""; fi
    ${SUDO} apt-get update || fail "apt-update"
    ${SUDO} apt-get install -y build-essential git xz-utils bc dkms || fail "apt-install"
fi

# ---------------------------------------------------------------------------
step "headers"
# ---------------------------------------------------------------------------
KHHEADERS_PATH="/sys/kernel/kheaders.tar.xz"
if [ ! -f "${KHHEADERS_PATH}" ]; then
    echo "Not found: ${KHHEADERS_PATH}"
    echo "Without the headers OrbStack ships for its own kernel, there is"
    echo "nothing correct to build against on this machine. A distribution"
    echo "header package would describe a kernel this machine is not running."
    fail "headers-missing"
fi

KH_DIR="${WORKDIR}/kheaders"
mkdir -p "${KH_DIR}"
tar -xJf "${KHHEADERS_PATH}" -C "${KH_DIR}" || fail "headers-extract"
echo "Headers extracted to: ${KH_DIR}"

# Find a plausible kernel source tree root for the build: a directory that
# contains include/linux and, ideally, a Makefile.
KSRC=""
KSRC="$(find "${KH_DIR}" -type d -name linux -path '*include*' 2>/dev/null | head -n 1 || true)"
if [ -n "${KSRC}" ]; then
    KSRC="$(dirname "$(dirname "${KSRC}")")"
fi
if [ -z "${KSRC}" ] || [ ! -d "${KSRC}/include" ]; then
    KSRC="${KH_DIR}"
    echo "Warning: could not pinpoint a header tree root; using ${KSRC}"
else
    echo "Header tree root (KSRC): ${KSRC}"
fi
if [ ! -e "${KSRC}/include/generated/autoconf.h" ] && ! find "${KH_DIR}" -name 'autoconf.h' 2>/dev/null | grep -q .; then
    echo "Warning: no autoconf.h found in the extracted headers. The build"
    echo "may fail at the compile step; that failure is itself a result."
fi

# ---------------------------------------------------------------------------
step "source"
# ---------------------------------------------------------------------------
SRC_DIR=""
if [ -n "${LOCAL_SRC}" ]; then
    if [ ! -d "${LOCAL_SRC}" ]; then
        echo "Local source directory does not exist: ${LOCAL_SRC}"
        fail "source-local-missing"
    fi
    SRC_DIR="${WORKDIR}/rtl8812au"
    cp -a "${LOCAL_SRC}" "${SRC_DIR}" || fail "source-local-copy"
    echo "Using local checkout copied from: ${LOCAL_SRC}"
else
    SRC_DIR="${WORKDIR}/rtl8812au"
    echo "Cloning the aircrack-ng rtl8812au driver at runtime."
    echo "Driver code is not vendored into the ShadowStrike package; it is"
    echo "fetched from its upstream project and stays under its own licence."
    git clone --depth 1 https://github.com/aircrack-ng/rtl8812au.git "${SRC_DIR}" || fail "source-clone"
fi

if [ ! -f "${SRC_DIR}/Makefile" ]; then
    echo "No Makefile in the driver source at ${SRC_DIR}"
    fail "source-no-makefile"
fi

# ---------------------------------------------------------------------------
step "build"
# ---------------------------------------------------------------------------
cd "${SRC_DIR}" || fail "build-cd"
echo "Building in: ${SRC_DIR}"
echo "Command: make KSRC=${KSRC} KVER=${KERNEL_RELEASE}"
echo "(The upstream Makefile accepts KSRC and KVER overrides. Headers"
echo "extracted from a tarball sometimes lack a prepared build tree, in"
echo "which case this step fails with missing generated files. Record the"
echo "exact error; it decides whether this route is viable at all.)"

if ! make KSRC="${KSRC}" KVER="${KERNEL_RELEASE}"; then
    echo "First attempt failed. Retrying once with KERNEL_SRC set, a"
    echo "variable some out-of-tree Makefiles read instead of KSRC."
    if ! make KERNEL_SRC="${KSRC}" KSRC="${KSRC}" KVER="${KERNEL_RELEASE}"; then
        fail "build-make"
    fi
fi

KO_FILE=""
KO_FILE="$(find "${SRC_DIR}" -name '*.ko' 2>/dev/null | head -n 1 || true)"
if [ -z "${KO_FILE}" ]; then
    fail "build-no-ko"
fi

echo
echo "Built module: ${KO_FILE}"
if command -v modinfo >/dev/null 2>&1; then
    modinfo "${KO_FILE}" 2>/dev/null | head -n 20 || true
    echo "Check the vermagic line above. It must match the running kernel"
    echo "(${KERNEL_RELEASE}) or the kernel will refuse the module."
fi

# ---------------------------------------------------------------------------
echo
echo "=============================================================="
echo " VERDICT: SUCCESS (module built, NOT loaded)"
echo " Module : ${KO_FILE}"
echo " Log    : ${LOG_FILE}"
echo "=============================================================="
echo
echo "This script deliberately stops here. To test the module yourself,"
echo "knowing it may be refused (unsigned, or a vermagic mismatch) and"
echo "that a USB Wi-Fi adapter must be passed through to this machine"
echo "first, run manually:"
echo
echo "  sudo insmod ${KO_FILE}"
echo
echo "Then verify with:"
echo
echo "  dmesg | tail -n 50"
echo "  lsmod | grep -i 88"
echo "  ip link        (look for a new wireless interface)"
echo "  iw dev         (confirm the interface and its modes)"
echo
echo "To remove it again:"
echo
echo "  sudo rmmod 88XXau   (module name as shown by lsmod)"
echo
echo "Remember: an OrbStack update replaces its kernel and headers, so a"
echo "module built this way must be rebuilt after OrbStack updates."

exit 0
