#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

source "${PROJECT_ROOT}/lib/test.sh"

test_init "Metrics"

################################################################################
# Fixtures: isolated state dir and metrics file, never the real ones.
################################################################################

TEST_STATE_DIR="${PROJECT_ROOT}/tests/tmp/metrics-state"
TEST_METRICS_FILE="${PROJECT_ROOT}/tests/tmp/metrics.prom"

rm -rf "${TEST_STATE_DIR}"
rm -f "${TEST_METRICS_FILE}"

export PROJECT_ROOT
export STATE_DIR="${TEST_STATE_DIR}"
export METRICS_FILE="${TEST_METRICS_FILE}"

source "${PROJECT_ROOT}/lib/utils.sh"
source "${PROJECT_ROOT}/lib/logger.sh"

LOGGER_HANDLER_CONSOLE=false

source "${PROJECT_ROOT}/lib/state.sh"
source "${PROJECT_ROOT}/lib/shutdown.sh"
source "${PROJECT_ROOT}/lib/metrics.sh"

state_load

################################################################################
# metrics_update / metrics_increment on the in-memory state
################################################################################

metrics_update last_event ONBATT
metrics_update last_event_at 1700000000

assert_equals \
    "metrics_update sets a gauge-like value" \
    "ONBATT" \
    "$(state_get metrics:last_event)"

assert_equals \
    "metrics_increment starts at 1 from unset" \
    "" \
    "$(state_get metrics:notify_sent)"

metrics_increment notify_sent

assert_equals \
    "metrics_increment sets 1 on first call" \
    "1" \
    "$(state_get metrics:notify_sent)"

metrics_increment notify_sent

assert_equals \
    "metrics_increment adds 1 on each call" \
    "2" \
    "$(state_get metrics:notify_sent)"

################################################################################
# metrics_collect formats Prometheus text, including shutdown.sh hosts
################################################################################

shutdown_start switch1
shutdown_start switch2
shutdown_execute switch2 "true" 5
SHUTDOWN_DRY_RUN=false
shutdown_execute switch2 "true" 5

COLLECTED="$(metrics_collect)"

assert_true \
    "collect includes the last event timestamp with its event label" \
    grep -q 'homelab_energy_last_event_timestamp{event="ONBATT"}' <<<"${COLLECTED}"

assert_true \
    "collect includes the notify_sent counter" \
    grep -q "homelab_energy_notifications_sent_total 2" <<<"${COLLECTED}"

assert_true \
    "collect includes an in_progress host as status code 1" \
    grep -q 'homelab_energy_shutdown_status{host="switch1"} 1' <<<"${COLLECTED}"

assert_true \
    "collect includes a completed host as status code 2" \
    grep -q 'homelab_energy_shutdown_status{host="switch2"} 2' <<<"${COLLECTED}"

################################################################################
# metrics_export writes the textfile atomically
################################################################################

assert_success \
    "metrics_export writes the metrics file" \
    metrics_export

assert_true \
    "the exported file is valid Prometheus text (has TYPE lines)" \
    grep -q "^# TYPE homelab_energy_shutdown_status gauge$" "${TEST_METRICS_FILE}"

assert_false \
    "metrics_export leaves no temp file behind" \
    bash -c 'ls "'"${PROJECT_ROOT}"'"/tests/tmp/.homelab_energy.* 2>/dev/null'

################################################################################
# Cleanup
################################################################################

rm -rf "${TEST_STATE_DIR}"
rm -f "${TEST_METRICS_FILE}"

test_summary
