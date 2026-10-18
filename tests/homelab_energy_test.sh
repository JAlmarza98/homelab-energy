#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

source "${PROJECT_ROOT}/lib/test.sh"

test_init "bin/homelab-energy"

################################################################################
# Fixtures: an isolated config (notifications on, fake ntfy topic) and a
# stubbed curl. Never touches the real config, hardware or network.
################################################################################

TEST_CONFIG_DIR="${PROJECT_ROOT}/tests/tmp/homelab-energy-config"
STUB_BIN="${PROJECT_ROOT}/tests/tmp/homelab-energy-bin"
CURL_LOG="${PROJECT_ROOT}/tests/tmp/homelab-energy-curl.log"

rm -rf "${TEST_CONFIG_DIR}" "${STUB_BIN}" "${CURL_LOG}"
mkdir -p "${TEST_CONFIG_DIR}/hosts" "${STUB_BIN}"

cat >"${TEST_CONFIG_DIR}/defaults.conf" <<'EOF'
PROJECT_NAME=homelab-energy
UPS_NAME=ups
SHUTDOWN_DELAY=60
LOG_LEVEL=WARN
PROXMOX_ENABLED=false
NAS_ENABLED=false
NOTIFICATIONS_ENABLED=true
PROMETHEUS_ENABLED=false
EOF

touch "${TEST_CONFIG_DIR}/hosts/$(hostname).conf"

SECRET_FILE="${PROJECT_ROOT}/tests/tmp/homelab-energy-secrets.env"
echo "NTFY_TOPIC=homelab-test" >"${SECRET_FILE}"
chmod 600 "${SECRET_FILE}"

cat >"${STUB_BIN}/curl" <<EOF
#!/usr/bin/env bash
echo "\$*" >>"${CURL_LOG}"
exit 0
EOF

chmod +x "${STUB_BIN}/curl"

# Runs bin/homelab-energy "$@" against the isolated config/secrets/PATH.
_run() {

    PATH="${STUB_BIN}:${PATH}" \
        CONFIG_DIR="${TEST_CONFIG_DIR}" \
        SECRETS_CONFIG_LOCAL="${SECRET_FILE}" \
        SECRETS_CONFIG_SYSTEM="/nonexistent/secrets.env" \
        "${PROJECT_ROOT}/bin/homelab-energy" "$@"

}

################################################################################
# Usage / argument errors
################################################################################

assert_false \
    "no arguments exits non-zero" \
    _run

assert_false \
    "event without a name exits non-zero" \
    _run event

################################################################################
# Known events notify
################################################################################

rm -f "${CURL_LOG}"

assert_success \
    "ONBATT handled successfully" \
    _run event ONBATT

assert_true \
    "ONBATT sends a notification" \
    grep -q "power lost" "${CURL_LOG}"

rm -f "${CURL_LOG}"

assert_success \
    "ONLINE handled successfully" \
    _run event ONLINE

assert_true \
    "ONLINE sends a notification" \
    grep -q "power restored" "${CURL_LOG}"

rm -f "${CURL_LOG}"

assert_success \
    "LOWBATT handled successfully" \
    _run event LOWBATT

assert_true \
    "LOWBATT sends a notification" \
    grep -q "battery low" "${CURL_LOG}"

################################################################################
# Unknown events never notify, but still succeed
################################################################################

rm -f "${CURL_LOG}"

assert_success \
    "unknown event still exits successfully" \
    _run event SOMETHING_ELSE

assert_false \
    "unknown event does not notify" \
    test -f "${CURL_LOG}"

################################################################################
# homelab-energy-cmdscript: upssched's single-argument CMDSCRIPT convention
################################################################################

_run_cmdscript() {

    PATH="${STUB_BIN}:${PATH}" \
        CONFIG_DIR="${TEST_CONFIG_DIR}" \
        SECRETS_CONFIG_LOCAL="${SECRET_FILE}" \
        SECRETS_CONFIG_SYSTEM="/nonexistent/secrets.env" \
        "${PROJECT_ROOT}/bin/homelab-energy-cmdscript" "$@"

}

rm -f "${CURL_LOG}"

assert_success \
    "cmdscript forwards a single argument as the event name" \
    _run_cmdscript ONBATT

assert_true \
    "cmdscript-forwarded ONBATT notifies" \
    grep -q "power lost" "${CURL_LOG}"

################################################################################
# Cleanup
################################################################################

rm -rf "${TEST_CONFIG_DIR}" "${STUB_BIN}" "${CURL_LOG}" "${SECRET_FILE}"

test_summary
