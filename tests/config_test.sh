#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

source "${PROJECT_ROOT}/lib/test.sh"

test_init "Config"

################################################################################
# Fixtures
################################################################################

TEST_CONFIG_DIR="${PROJECT_ROOT}/tests/tmp/config"

rm -rf "${TEST_CONFIG_DIR}"
mkdir -p "${TEST_CONFIG_DIR}/hosts"

cat >"${TEST_CONFIG_DIR}/defaults.conf" <<'EOF'
PROJECT_NAME=example

UPS_NAME=ups

SHUTDOWN_DELAY=60

LOG_LEVEL=WARN

PROXMOX_ENABLED=false
NAS_ENABLED=false
NOTIFICATIONS_ENABLED=false
PROMETHEUS_ENABLED=false
EOF

cat >"${TEST_CONFIG_DIR}/energy.conf" <<'EOF'
# Site overrides.
UPS_NAME=apc
SHUTDOWN_DELAY=300
EOF

cat >"${TEST_CONFIG_DIR}/hosts/$(hostname).conf" <<'EOF'
PROXMOX_IP=10.0.0.10
EOF

# Runs "$@" (a command or function) inside a fresh shell, after load_config
# has parsed the layers rooted at $1. Isolates each test from the others and
# from the real config/secrets files.
_config_run() {

    local dir="$1"
    shift

    CONFIG_DIR="${dir}" PROJECT_ROOT="${PROJECT_ROOT}" \
        SECRETS_CONFIG_LOCAL="${SECRETS_CONFIG_LOCAL:-${dir}/.env}" \
        SECRETS_CONFIG_SYSTEM="${SECRETS_CONFIG_SYSTEM:-/nonexistent/secrets.env}" \
        bash -c '
            source "${PROJECT_ROOT}/lib/config.sh"
            load_config
            "$@"
        ' _config_run "$@"

}

################################################################################
# Layering
################################################################################

assert_equals \
    "default-only key keeps its default" \
    "example" \
    "$(_config_run "${TEST_CONFIG_DIR}" config_get PROJECT_NAME)"

assert_equals \
    "energy.conf overrides defaults.conf" \
    "apc" \
    "$(_config_run "${TEST_CONFIG_DIR}" config_get UPS_NAME)"

assert_equals \
    "energy.conf overrides defaults.conf (int)" \
    "300" \
    "$(_config_run "${TEST_CONFIG_DIR}" config_get SHUTDOWN_DELAY)"

assert_equals \
    "hosts/<hostname>.conf provides host-only keys" \
    "10.0.0.10" \
    "$(_config_run "${TEST_CONFIG_DIR}" config_get PROXMOX_IP)"

################################################################################
# config_get / config_exists
################################################################################

assert_success \
    "config_exists true for a defined key" \
    _config_run "${TEST_CONFIG_DIR}" config_exists UPS_NAME

assert_false \
    "config_exists false for an unknown key" \
    _config_run "${TEST_CONFIG_DIR}" config_exists NOPE_KEY

assert_equals \
    "config_get empty for an unknown key" \
    "" \
    "$(_config_run "${TEST_CONFIG_DIR}" config_get NOPE_KEY)"

################################################################################
# Validation
################################################################################

BAD_CONFIG_DIR="${PROJECT_ROOT}/tests/tmp/config-bad"

rm -rf "${BAD_CONFIG_DIR}"
mkdir -p "${BAD_CONFIG_DIR}/hosts"

cp "${TEST_CONFIG_DIR}/defaults.conf" "${BAD_CONFIG_DIR}/defaults.conf"
cp "${TEST_CONFIG_DIR}/hosts/$(hostname).conf" "${BAD_CONFIG_DIR}/hosts/$(hostname).conf"

cat >"${BAD_CONFIG_DIR}/energy.conf" <<'EOF'
SHUTDOWN_DELAY=not-a-number
EOF

assert_false \
    "rejects a non-integer SHUTDOWN_DELAY" \
    _config_run "${BAD_CONFIG_DIR}" config_get SHUTDOWN_DELAY

MISSING_CONFIG_DIR="${PROJECT_ROOT}/tests/tmp/config-missing"

rm -rf "${MISSING_CONFIG_DIR}"
mkdir -p "${MISSING_CONFIG_DIR}"

assert_false \
    "fails when defaults.conf is missing" \
    _config_run "${MISSING_CONFIG_DIR}" config_get UPS_NAME

################################################################################
# Secrets
################################################################################

SECRET_FILE="${PROJECT_ROOT}/tests/tmp/secrets.env"

echo "TELEGRAM_BOT_TOKEN=homelab-test" >"${SECRET_FILE}"
chmod 600 "${SECRET_FILE}"

assert_equals \
    "a private secrets file is loaded" \
    "homelab-test" \
    "$(SECRETS_CONFIG_LOCAL="${SECRET_FILE}" _config_run "${TEST_CONFIG_DIR}" config_get TELEGRAM_BOT_TOKEN)"

chmod 644 "${SECRET_FILE}"

_config_run_with_loose_secret() {
    SECRETS_CONFIG_LOCAL="${SECRET_FILE}" _config_run "${TEST_CONFIG_DIR}" config_get TELEGRAM_BOT_TOKEN
}

assert_false \
    "a group/world-readable secrets file is refused" \
    _config_run_with_loose_secret

rm -f "${SECRET_FILE}"

################################################################################
# Cleanup
################################################################################

rm -rf "${TEST_CONFIG_DIR}" "${BAD_CONFIG_DIR}" "${MISSING_CONFIG_DIR}"

################################################################################
# Summary
################################################################################

test_summary
