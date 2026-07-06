#!/bin/bash
# Keep fans at maximum (EC keep-alive every 60s)
# Part of hp-omen-fan-linux

KEEPALIVE_SEC=60
LOG_FILE="/var/log/omen-fan-max.log"
STATE_FILE="/run/omen-fan-max.mode"

log() { echo "[$(date '+%F %T')] $*" >> "$LOG_FILE"; }

setup() {
    mountpoint -q /sys/kernel/debug 2>/dev/null || mount -t debugfs none /sys/kernel/debug 2>/dev/null || true
    lsmod | grep -q '^ec_sys' || modprobe ec_sys write_support=1 2>/dev/null || true
}

ec_boost_on() {
    python3 - <<'PY' 2>/dev/null || true
with open("/sys/kernel/debug/ec/ec0/io", "r+b") as ec:
    ec.seek(236)
    ec.write(bytes([1]))
PY
    echo max > "$STATE_FILE" 2>/dev/null || true
}

trap 'ec_boost_on; log "signal"; exit 0' TERM INT

setup
log "daemon started (keep-alive ${KEEPALIVE_SEC}s)"
ec_boost_on

while true; do
    ec_boost_on
    sleep "$KEEPALIVE_SEC"
done
