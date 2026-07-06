#!/bin/bash
# Collect hardware evidence for bug reports and kernel contributions.
# Usage: sudo ./collect-evidence.sh [output-file]

set -euo pipefail

OUT="${1:-}"
if [[ -z "$OUT" ]]; then
    BOARD="$(cat /sys/class/dmi/id/board_name 2>/dev/null || echo unknown)"
    OUT="$(dirname "$0")/../data/evidence-${BOARD}-$(date +%Y%m%d).txt"
fi

mkdir -p "$(dirname "$OUT")"

{
    echo "=== HP OMEN Fan Evidence ==="
    echo "Collected: $(date -Iseconds)"
    echo "Hostname: $(hostname)"
    echo ""

    echo "=== DMI ==="
    for f in board_name product_name product_version bios_version sys_vendor; do
        echo -n "$f: "
        cat "/sys/class/dmi/id/$f" 2>/dev/null || echo N/A
    done
    echo ""

    echo "=== Kernel ==="
    uname -a
    echo ""

    echo "=== Modules ==="
    lsmod | grep -E 'hp_wmi|ec_sys|wmi' || true
    echo ""

    echo "=== hp-wmi hwmon ==="
    find /sys/devices/platform/hp-wmi/hwmon -type f 2>/dev/null | while read -r f; do
        echo "--- $f ---"
        cat "$f" 2>/dev/null || echo "(read error)"
    done
    echo ""

    echo "=== platform_profile ==="
    cat /sys/firmware/acpi/platform_profile 2>/dev/null || echo "N/A"
    cat /sys/firmware/acpi/platform_profile_choices 2>/dev/null || true
    echo ""

    echo "=== sensors ==="
    sensors 2>/dev/null || echo "lm-sensors not available"
    echo ""

    echo "=== pwm1_enable test (needs root) ==="
    HWMON="$(find /sys/devices/platform/hp-wmi/hwmon -name pwm1_enable 2>/dev/null | head -1)"
    if [[ -n "$HWMON" && "${EUID:-0}" -eq 0 ]]; then
        echo "Path: $HWMON"
        echo -n "current: "; cat "$HWMON"
        echo -n "write 0 (max): "
        echo 0 > "$HWMON" 2>&1 || true
        echo -n "after: "; cat "$HWMON"
        echo 2 > "$HWMON" 2>/dev/null || true
    else
        echo "Run with sudo for pwm test"
    fi
    echo ""

    echo "=== EC access ==="
    if [[ "${EUID:-0}" -eq 0 ]]; then
        mountpoint -q /sys/kernel/debug 2>/dev/null || mount -t debugfs none /sys/kernel/debug 2>/dev/null || true
        modprobe ec_sys write_support=1 2>/dev/null || true
        if [[ -r /sys/kernel/debug/ec/ec0/io ]]; then
            echo "EC 0xEC (boost): $(od -An -tu1 -N1 -j236 /sys/kernel/debug/ec/ec0/io 2>/dev/null | tr -d ' ')"
            echo "EC 0x62 (bios):  $(od -An -tu1 -N1 -j98 /sys/kernel/debug/ec/ec0/io 2>/dev/null | tr -d ' ')"
        else
            echo "EC io not accessible"
        fi
    else
        echo "Run with sudo for EC dump"
    fi
    echo ""

    echo "=== dmesg hp-wmi (last 20) ==="
    dmesg 2>/dev/null | grep -iE 'hp.wmi|hp_wmi|wmi.*hp' | tail -20 || true

} | tee "$OUT"

echo "Evidence written to: $OUT"
