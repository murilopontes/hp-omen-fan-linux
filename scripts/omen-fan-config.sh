#!/bin/bash
# HP OMEN max fan configuration (hp-omen-fan-linux project)
#
# Usage:
#   sudo ./omen-fan-config.sh max
#   sudo ./omen-fan-config.sh auto
#   sudo ./omen-fan-config.sh install
#   ./omen-fan-config.sh status

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

readonly EC_IO="/sys/kernel/debug/ec/ec0/io"
readonly BOOST_OFFSET=236
readonly BIOS_OFFSET=98
readonly FAN1_OFFSET=52
readonly FAN2_OFFSET=53
readonly SERVICE_NAME="omen-fan-max"
readonly DAEMON_SCRIPT="$SCRIPT_DIR/omen-fan-daemon.sh"
readonly STATE_FILE="/run/omen-fan-max.mode"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[ok]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[x]${NC} $*" >&2; }

need_root() {
    [[ "${EUID:-$(id -u)}" -ne 0 ]] || return 0
    err "Run with sudo: sudo $0 $*"
    exit 1
}

find_hp_hwmon() {
    local base
    for base in /sys/devices/platform/hp-wmi/hwmon/hwmon*; do
        [[ -d "$base" && -f "$base/pwm1_enable" ]] || continue
        echo "$base"
        return 0
    done
    return 1
}

setup_kernel_access() {
    mountpoint -q /sys/kernel/debug 2>/dev/null || \
        mount -t debugfs none /sys/kernel/debug 2>/dev/null || true
    lsmod | grep -q '^ec_sys' || modprobe ec_sys write_support=1 || {
        err "ec_sys unavailable. Disable Secure Boot."
        exit 1
    }
}

ec_write() {
    python3 - "$1" "$2" <<'PY'
import sys
with open("/sys/kernel/debug/ec/ec0/io", "r+b") as ec:
    ec.seek(int(sys.argv[1]))
    ec.write(bytes([int(sys.argv[2])]))
PY
}

ec_read() {
    python3 - "$1" <<'PY'
import sys
with open("/sys/kernel/debug/ec/ec0/io", "rb") as ec:
    ec.seek(int(sys.argv[1]))
    print(ec.read(1)[0])
PY
}

set_mode_state() { echo "$1" > "$STATE_FILE"; }
get_mode_state() { [[ -f "$STATE_FILE" ]] && cat "$STATE_FILE" || echo "auto"; }

set_fan_max() {
    setup_kernel_access
    ec_write "$BOOST_OFFSET" 1
    set_mode_state "max"
    local hwmon
    hwmon="$(find_hp_hwmon)" && echo 0 > "$hwmon/pwm1_enable" 2>/dev/null || true
    sleep 2
    log "Fans at maximum (EC 0xEC=1)"
    show_status
}

set_fan_auto() {
    need_root
    setup_kernel_access
    ec_write "$BOOST_OFFSET" 0
    ec_write "$BIOS_OFFSET" 0
    ec_write "$FAN1_OFFSET" 0
    ec_write "$FAN2_OFFSET" 0
    set_mode_state "auto"
    local hwmon
    hwmon="$(find_hp_hwmon)" && echo 2 > "$hwmon/pwm1_enable" 2>/dev/null || true
    sleep 2
    log "Control returned to BIOS"
    show_status
}

show_status() {
    echo ""
    echo -e "${CYAN}=== HP OMEN Fan (${PROJECT_DIR##*/}) ===${NC}"
    echo "  Product: $(cat /sys/class/dmi/id/product_name 2>/dev/null || echo ?)"
    echo "  Board  : $(cat /sys/class/dmi/id/board_name 2>/dev/null || echo ?)"
    local mode
    mode="$(get_mode_state)"
    if systemctl is-active --quiet "$SERVICE_NAME.service" 2>/dev/null; then
        echo -e "  Mode   : ${RED}MAX (systemd)${NC}"
    elif [[ "$mode" == "max" ]]; then
        echo -e "  Mode   : ${RED}MAX${NC}"
    else
        echo -e "  Mode   : ${GREEN}auto${NC}"
    fi
    [[ "${EUID:-0}" -eq 0 && -r "$EC_IO" ]] && \
        echo "  EC 0xEC: $(ec_read "$BOOST_OFFSET")"
    echo ""
    sensors hp-isa-0000 2>/dev/null | grep -E '^fan[12]:' | sed 's/^/  /' || warn "hp sensors unavailable"
    echo ""
}

install_service() {
    need_root
    chmod +x "$DAEMON_SCRIPT"
    cat > /etc/modprobe.d/ec_sys.conf << 'EOF'
options ec_sys write_support=1
EOF
    cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=HP OMEN fan max (hp-omen-fan-linux)
After=multi-user.target

[Service]
Type=simple
ExecStartPre=/bin/bash -c 'mountpoint -q /sys/kernel/debug || mount -t debugfs none /sys/kernel/debug'
ExecStartPre=/sbin/modprobe ec_sys write_support=1
ExecStart=$DAEMON_SCRIPT
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now "$SERVICE_NAME.service"
    log "Service installed: $SERVICE_NAME"
    show_status
}

uninstall_service() {
    need_root
    systemctl disable --now "$SERVICE_NAME.service" 2>/dev/null || true
    rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
    systemctl daemon-reload
    set_fan_auto
    log "Service removed"
}

usage() {
    cat << EOF
hp-omen-fan-linux — HP OMEN fan control

  max | auto | install | uninstall | status | monitor

Docs: $PROJECT_DIR/docs/
EOF
}

main() {
    case "${1:-status}" in
        max|on)       need_root; set_fan_max ;;
        auto|off)     need_root; set_fan_auto ;;
        install)      install_service ;;
        uninstall)    uninstall_service ;;
        status)       show_status ;;
        monitor)      while true; do clear; show_status; sleep 2; done ;;
        -h|--help)    usage ;;
        *)            err "unknown command: $1"; usage; exit 1 ;;
    esac
}

main "$@"
