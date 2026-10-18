#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

source "${PROJECT_ROOT}/lib/test.sh"

test_init "NUT"

################################################################################
# Stub upsc in a temporary PATH: never touches real hardware.
################################################################################

STUB_BIN="${PROJECT_ROOT}/tests/tmp/nut-bin"

rm -rf "${STUB_BIN}"
mkdir -p "${STUB_BIN}"

cat >"${STUB_BIN}/upsc" <<'EOF'
#!/usr/bin/env bash
case "$2" in
ups.status) echo "${NUT_STUB_STATUS:-OL}" ;;
battery.charge) echo "90" ;;
battery.runtime) echo "1800" ;;
input.voltage) echo "230.0" ;;
ups.load) echo "15" ;;
*) exit 1 ;;
esac
EOF

chmod +x "${STUB_BIN}/upsc"

cat >"${STUB_BIN}/upsc-unreachable" <<'EOF'
#!/usr/bin/env bash
echo "Error: Connection failure" >&2
exit 1
EOF

chmod +x "${STUB_BIN}/upsc-unreachable"

# Runs "$@" with the stub upsc on PATH and UPS_NAME/NUT_SERVER set, isolated
# from the real NUT server and from the surrounding shell's PATH.
_nut_run() {

    PATH="${STUB_BIN}:${PATH}" UPS_NAME=apc NUT_SERVER=localhost \
        NUT_STUB_STATUS="${NUT_STUB_STATUS:-OL}" \
        bash -c '
            source "'"${PROJECT_ROOT}"'/lib/nut.sh"
            "$@"
        ' _nut_run "$@"

}

################################################################################
# Online
################################################################################

assert_equals \
    "nut_get_status reads ups.status" \
    "OL" \
    "$(_nut_run nut_get_status)"

assert_success \
    "nut_is_online true when status is OL" \
    _nut_run nut_is_online

assert_false \
    "nut_is_on_battery false when status is OL" \
    _nut_run nut_is_on_battery

################################################################################
# On battery
################################################################################

NUT_STUB_STATUS="OB LB"

assert_success \
    "nut_is_on_battery true when status contains OB" \
    _nut_run nut_is_on_battery

assert_false \
    "nut_is_online false when on battery" \
    _nut_run nut_is_online

unset NUT_STUB_STATUS

################################################################################
# Readings
################################################################################

assert_equals \
    "nut_get_charge reads battery.charge" \
    "90" \
    "$(_nut_run nut_get_charge)"

assert_equals \
    "nut_get_runtime reads battery.runtime" \
    "1800" \
    "$(_nut_run nut_get_runtime)"

assert_equals \
    "nut_get_voltage reads input.voltage" \
    "230.0" \
    "$(_nut_run nut_get_voltage)"

assert_equals \
    "nut_get_load reads ups.load" \
    "15" \
    "$(_nut_run nut_get_load)"

################################################################################
# Unreachable UPS: never silently reports "online"
################################################################################

_nut_run_unreachable() {

    PATH="${STUB_BIN}:${PATH}" UPS_NAME=apc NUT_SERVER=localhost \
        bash -c '
            source "'"${PROJECT_ROOT}"'/lib/nut.sh"
            upsc() { upsc-unreachable "$@"; }
            "$@"
        ' _nut_run_unreachable "$@"

}

assert_false \
    "nut_is_online fails (not true) when upsc is unreachable" \
    _nut_run_unreachable nut_is_online

rm -rf "${STUB_BIN}"

test_summary
