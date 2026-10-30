#!/usr/bin/env bash
# ShadowStrike OS - Kernel Parity Toolkit
# audit.sh - READ-ONLY kernel feature audit for an OrbStack Kali machine.
#
# What it does:
#   Reports the running kernel, looks for OrbStack markers, finds the kernel
#   configuration from the first available source, and checks a defined list
#   of kernel features that matter for Kali work.
#
# What it never does:
#   No module loads. No package installs. No service changes.
#   No writes outside a single temporary directory that is removed on exit.
#
# Exit status: 0 on a completed audit (even when features are missing),
# non-zero only on a hard failure (for example, no temporary directory).

set -u

TMPDIR_WORK=""
cleanup() {
    if [ -n "${TMPDIR_WORK}" ] && [ -d "${TMPDIR_WORK}" ]; then
        rm -rf "${TMPDIR_WORK}"
    fi
}
trap cleanup EXIT INT TERM

if ! TMPDIR_WORK="$(mktemp -d 2>/dev/null)"; then
    echo "FATAL: could not create a temporary directory" >&2
    exit 1
fi

CONFIG_FILE="${TMPDIR_WORK}/kernel-config.txt"
CONFIG_SOURCE="none"
PRESENT_COUNT=0
CHECKED_COUNT=0

echo "=============================================================="
echo " ShadowStrike OS - Kernel Parity Audit"
echo " Read-only. Nothing is installed, loaded, or changed."
echo "=============================================================="
echo

# ---------------------------------------------------------------------------
# 1. Kernel and platform identity
# ---------------------------------------------------------------------------
KERNEL_RELEASE="$(uname -r 2>/dev/null || echo unknown)"
KERNEL_ALL="$(uname -a 2>/dev/null || echo unknown)"
ARCH="$(uname -m 2>/dev/null || echo unknown)"

echo "Kernel release : ${KERNEL_RELEASE}"
echo "Kernel string  : ${KERNEL_ALL}"
echo "Architecture   : ${ARCH}"
echo

# OrbStack detection: best effort only. We collect markers, we do not guess.
ORBSTACK_MARKERS=""
check_marker() {
    # $1 = label, $2 = haystack text
    case "$2" in
        *[Oo]rb[Ss]tack*|*orbstack*)
            ORBSTACK_MARKERS="${ORBSTACK_MARKERS} $1"
            ;;
    esac
}

CMDLINE_TEXT=""
if [ -r /proc/cmdline ]; then
    CMDLINE_TEXT="$(cat /proc/cmdline 2>/dev/null || true)"
    check_marker "proc-cmdline" "${CMDLINE_TEXT}"
fi

DMESG_TEXT=""
if command -v dmesg >/dev/null 2>&1; then
    DMESG_TEXT="$(dmesg 2>/dev/null | head -n 200 || true)"
    check_marker "dmesg" "${DMESG_TEXT}"
fi

if [ -r /proc/sys/kernel/osrelease ]; then
    check_marker "osrelease" "$(cat /proc/sys/kernel/osrelease 2>/dev/null || true)"
fi

# OrbStack Linux machines commonly expose their headers here; treat the
# shipped headers file itself as a supporting (not conclusive) marker.
KHHEADERS_PATH="/sys/kernel/kheaders.tar.xz"
KHHEADERS_PRESENT="no"
if [ -f "${KHHEADERS_PATH}" ]; then
    KHHEADERS_PRESENT="yes"
fi

if [ -n "${ORBSTACK_MARKERS}" ]; then
    echo "Platform       : OrbStack markers found:${ORBSTACK_MARKERS}"
elif [ "${KHHEADERS_PRESENT}" = "yes" ]; then
    echo "Platform       : not confirmed as OrbStack (no text markers found),"
    echo "                 but shipped kernel headers are present, which is"
    echo "                 consistent with an OrbStack machine."
else
    echo "Platform       : not OrbStack (no markers found), or markers not readable"
fi
echo

# ---------------------------------------------------------------------------
# 2. Locate the kernel configuration, in order
# ---------------------------------------------------------------------------
# Order required by the toolkit design:
#   1. /proc/config.gz
#   2. /boot/config-*
#   3. The config inside OrbStack's shipped headers tarball

normalize_autoconf() {
    # Convert an autoconf.h style file into CONFIG_X=y style lines.
    # Input: $1, output appended to $CONFIG_FILE
    while IFS= read -r line; do
        case "${line}" in
            "#define CONFIG_"*)
                rest="${line#\#define }"
                name="${rest%% *}"
                value="${rest#* }"
                if [ "${value}" = "1" ]; then
                    echo "${name}=y" >> "${CONFIG_FILE}"
                elif [ "${value}" = "2" ]; then
                    echo "${name}=m" >> "${CONFIG_FILE}"
                fi
                ;;
            "#define CONFIG_"*"_MODULE 1")
                ;;
        esac
    done < "$1"
    # Module symbols in autoconf.h appear as CONFIG_X_MODULE defines.
    grep -h '^#define CONFIG_.*_MODULE 1' "$1" 2>/dev/null | while IFS= read -r line; do
        rest="${line#\#define }"
        name="${rest%% *}"
        base="${name%_MODULE}"
        echo "${base}=m" >> "${CONFIG_FILE}"
    done
}

if [ -r /proc/config.gz ]; then
    if gzip -dc /proc/config.gz > "${CONFIG_FILE}" 2>/dev/null && [ -s "${CONFIG_FILE}" ]; then
        CONFIG_SOURCE="/proc/config.gz"
    fi
fi

if [ "${CONFIG_SOURCE}" = "none" ]; then
    for candidate in "/boot/config-${KERNEL_RELEASE}" /boot/config-*; do
        if [ -r "${candidate}" ]; then
            if cp "${candidate}" "${CONFIG_FILE}" 2>/dev/null && [ -s "${CONFIG_FILE}" ]; then
                CONFIG_SOURCE="${candidate}"
                break
            fi
        fi
    done
fi

if [ "${CONFIG_SOURCE}" = "none" ] && [ -f "${KHHEADERS_PATH}" ]; then
    KH_DIR="${TMPDIR_WORK}/kheaders"
    mkdir -p "${KH_DIR}"
    if tar -xJf "${KHHEADERS_PATH}" -C "${KH_DIR}" 2>/dev/null; then
        FOUND_CONFIG=""
        FOUND_CONFIG="$(find "${KH_DIR}" -name '.config' -o -name 'config' 2>/dev/null | head -n 1 || true)"
        if [ -n "${FOUND_CONFIG}" ] && [ -s "${FOUND_CONFIG}" ]; then
            cp "${FOUND_CONFIG}" "${CONFIG_FILE}"
            CONFIG_SOURCE="kheaders:${FOUND_CONFIG##*/} (from ${KHHEADERS_PATH})"
        else
            FOUND_AUTOCONF=""
            FOUND_AUTOCONF="$(find "${KH_DIR}" -name 'autoconf.h' 2>/dev/null | head -n 1 || true)"
            if [ -n "${FOUND_AUTOCONF}" ]; then
                : > "${CONFIG_FILE}"
                normalize_autoconf "${FOUND_AUTOCONF}"
                if [ -s "${CONFIG_FILE}" ]; then
                    CONFIG_SOURCE="kheaders:autoconf.h (from ${KHHEADERS_PATH})"
                fi
            fi
        fi
    fi
fi

echo "Config source  : ${CONFIG_SOURCE}"
if [ "${CONFIG_SOURCE}" = "none" ]; then
    echo "                 No readable kernel config was found. Every feature"
    echo "                 below will be reported as UNKNOWN, by design."
fi
echo

# ---------------------------------------------------------------------------
# 3. Feature checks
# ---------------------------------------------------------------------------
# Each entry: Label|CONFIG_A CONFIG_B ...|mode
# mode "any" = PRESENT if at least one listed config is y or m.
# mode "all" = PRESENT only if every listed config is y or m.
# A config explicitly present as "is not set" counts toward MISSING when no
# listed config is enabled. No config source at all means UNKNOWN.

FEATURES="
Wireless core (cfg80211)|CONFIG_CFG80211|all
Wireless MAC layer (mac80211)|CONFIG_MAC80211|all
MediaTek mt76 driver family|CONFIG_MT76_CORE CONFIG_MT76|any
MediaTek MT7921U USB Wi-Fi|CONFIG_MT7921U CONFIG_MT7921_COMMON|any
Realtek RTL88xx family (in-tree rtw88 / rtl8xxxu)|CONFIG_RTW88 CONFIG_RTL8XXXU|any
Radiotap and monitor mode plumbing|CONFIG_CFG80211 CONFIG_MAC80211|all
nftables|CONFIG_NF_TABLES|all
Legacy iptables|CONFIG_IP_NF_IPTABLES|all
TUN/TAP device|CONFIG_TUN|all
WireGuard|CONFIG_WIREGUARD|all
Bluetooth core|CONFIG_BT|all
Bluetooth HCI over USB|CONFIG_BT_HCIBTUSB|all
USB gadget framework|CONFIG_USB_GADGET|all
USB HID gadget function|CONFIG_USB_G_HID CONFIG_USB_CONFIGFS_F_HID|any
Packet sockets (AF_PACKET)|CONFIG_PACKET|all
BPF syscall|CONFIG_BPF_SYSCALL|all
User namespaces|CONFIG_USER_NS|all
Network namespaces|CONFIG_NET_NS|all
KVM virtualization|CONFIG_KVM|all
Kernel headers in kernel (IKHEADERS)|CONFIG_IKHEADERS|all
"

config_state() {
    # $1 = CONFIG name. Prints: enabled, disabled, absent
    if [ "${CONFIG_SOURCE}" = "none" ]; then
        echo "absent"
        return
    fi
    if grep -Eq "^${1}=(y|m)" "${CONFIG_FILE}" 2>/dev/null; then
        echo "enabled"
    elif grep -Eq "^# ${1} is not set" "${CONFIG_FILE}" 2>/dev/null; then
        echo "disabled"
    else
        echo "absent"
    fi
}

echo "Kernel features"
echo "--------------------------------------------------------------"
printf '%s\n' "${FEATURES}" | while IFS= read -r entry; do
    # The while loop runs in a subshell because of the pipe; counters are
    # handled by writing result lines to a tally file in the temp dir.
    [ -z "${entry}" ] && continue
    label="${entry%%|*}"
    rest="${entry#*|}"
    configs="${rest%%|*}"
    mode="${rest##*|}"

    enabled_any="no"
    disabled_any="no"
    enabled_all="yes"
    for cfg in ${configs}; do
        state="$(config_state "${cfg}")"
        if [ "${state}" = "enabled" ]; then
            enabled_any="yes"
        else
            enabled_all="no"
        fi
        if [ "${state}" = "disabled" ]; then
            disabled_any="yes"
        fi
    done

    if [ "${CONFIG_SOURCE}" = "none" ]; then
        verdict="UNKNOWN"
    elif [ "${mode}" = "any" ]; then
        if [ "${enabled_any}" = "yes" ]; then
            verdict="PRESENT"
        elif [ "${disabled_any}" = "yes" ]; then
            verdict="MISSING"
        else
            verdict="UNKNOWN"
        fi
    else
        if [ "${enabled_all}" = "yes" ]; then
            verdict="PRESENT"
        elif [ "${disabled_any}" = "yes" ] || [ "${enabled_any}" = "no" ]; then
            # "all" mode: if the config source is readable and a required
            # symbol is not enabled, treat an explicit not-set as MISSING
            # and a merely absent symbol as UNKNOWN only when nothing was
            # explicitly disabled.
            if [ "${disabled_any}" = "yes" ]; then
                verdict="MISSING"
            else
                verdict="UNKNOWN"
            fi
        else
            verdict="UNKNOWN"
        fi
    fi

    printf '%-52s %-8s (%s)\n' "${label}" "${verdict}" "${configs}"
    echo "${verdict}" >> "${TMPDIR_WORK}/tally.txt"
done

if [ -f "${TMPDIR_WORK}/tally.txt" ]; then
    CHECKED_COUNT="$(wc -l < "${TMPDIR_WORK}/tally.txt" | tr -d ' ')"
    PRESENT_COUNT="$(grep -c '^PRESENT$' "${TMPDIR_WORK}/tally.txt" || true)"
else
    CHECKED_COUNT=0
    PRESENT_COUNT=0
fi
echo

# ---------------------------------------------------------------------------
# 4. Module loading capability, tested without loading anything
# ---------------------------------------------------------------------------
echo "Module loading capability (no module was loaded by this audit)"
echo "--------------------------------------------------------------"

if [ -d /sys/module ]; then
    LOADED_COUNT="$(find /sys/module -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')"
    echo "/sys/module            : present (${LOADED_COUNT} module entries visible)"
else
    echo "/sys/module            : not present (monolithic kernel, or restricted view)"
fi

for tool in modprobe insmod lsmod; do
    if command -v "${tool}" >/dev/null 2>&1; then
        echo "${tool} binary          : present ($(command -v "${tool}"))"
    else
        echo "${tool} binary          : not found in PATH"
    fi
done

MODULES_DISABLED="unknown"
if [ -r /proc/sys/kernel/modules_disabled ]; then
    MODULES_DISABLED="$(cat /proc/sys/kernel/modules_disabled 2>/dev/null || echo unknown)"
fi
echo "modules_disabled sysctl: ${MODULES_DISABLED} (1 means module loading is locked off)"

echo "Shipped headers        : ${KHHEADERS_PATH} present: ${KHHEADERS_PRESENT}"
if [ "${KHHEADERS_PRESENT}" = "yes" ]; then
    echo "                         Headers present means out-of-tree modules can"
    echo "                         be attempted against the running kernel."
fi

if command -v modprobe >/dev/null 2>&1; then
    echo "Dry check (modprobe -n): skipped by design; a dry run still resolves"
    echo "                         dependencies and is not needed for this audit."
fi
echo

# ---------------------------------------------------------------------------
# 5. Summary
# ---------------------------------------------------------------------------
echo "=============================================================="
echo " SUMMARY: present ${PRESENT_COUNT} of ${CHECKED_COUNT} checked features"
echo " Config source: ${CONFIG_SOURCE}"
echo " Platform markers: ${ORBSTACK_MARKERS:-none found}"
echo " Next step: feed any MISSING rows into PARITY.md, route by route."
echo "=============================================================="

exit 0
