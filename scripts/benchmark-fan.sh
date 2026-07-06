#!/bin/bash
# Compare RPM in auto mode vs EC boost maximum.
# Usage: sudo ./benchmark-fan.sh

set -euo pipefail

EC_IO="/sys/kernel/debug/ec/ec0/io"
BOOST=236
REPORT_DIR="$(cd "$(dirname "$0")/../data" && pwd)"
REPORT="$REPORT_DIR/benchmark-$(date +%Y%m%d-%H%M%S).txt"

if [[ "${EUID:-0}" -ne 0 ]]; then
    echo "Run with sudo" >&2
    exit 1
fi

mountpoint -q /sys/kernel/debug 2>/dev/null || mount -t debugfs none /sys/kernel/debug
modprobe ec_sys write_support=1 2>/dev/null || true

read_rpm() {
    sensors hp-isa-0000 2>/dev/null | grep -E '^fan[12]:' || echo "N/A"
}

ec_set() {
    python3 -c "
with open('$EC_IO','r+b') as f:
    f.seek($BOOST)
    f.write(bytes([$1]))
"
}

{
    echo "HP OMEN Fan Benchmark"
    echo "Date: $(date -Iseconds)"
    echo "Board: $(cat /sys/class/dmi/id/board_name)"
    echo "Product: $(cat /sys/class/dmi/id/product_name)"
    echo "Kernel: $(uname -r)"
    echo ""

    echo "=== AUTO (EC boost=0) ==="
    ec_set 0
    sleep 15
    read_rpm
    sensors coretemp-isa-0000 2>/dev/null | grep Package || true
    echo ""

    echo "=== MAX (EC boost=1) ==="
    ec_set 1
    sleep 8
    read_rpm
    sensors coretemp-isa-0000 2>/dev/null | grep Package || true
    echo ""

    echo "=== RESTORE AUTO ==="
    ec_set 0
    sleep 10
    read_rpm
    echo ""

    echo "=== pwm1_enable kernel test ==="
    HWMON="$(find /sys/devices/platform/hp-wmi/hwmon -name pwm1_enable 2>/dev/null | head -1)"
    if [[ -n "$HWMON" ]]; then
        echo "echo 0 > $HWMON"
        echo 0 > "$HWMON" 2>&1 || echo "FAILED: $?"
        echo 2 > "$HWMON" 2>/dev/null || true
    fi

} | tee "$REPORT"

echo ""
echo "Report: $REPORT"
