#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

source "${PROJECT_ROOT}/lib/test.sh"

test_init "Notify"

################################################################################
# Stub curl in a temporary PATH: never sends a real HTTP request.
################################################################################

STUB_BIN="${PROJECT_ROOT}/tests/tmp/notify-bin"
CURL_LOG="${PROJECT_ROOT}/tests/tmp/notify-curl.log"

rm -rf "${STUB_BIN}" "${CURL_LOG}"
mkdir -p "${STUB_BIN}"

cat >"${STUB_BIN}/curl" <<EOF
#!/usr/bin/env bash
echo "\$*" >>"${CURL_LOG}"
exit "\${NOTIFY_STUB_CURL_EXIT:-0}"
EOF

chmod +x "${STUB_BIN}/curl"

# Runs "$@" (a notify_* call) with the stub curl on PATH, after sourcing
# logger.sh (for log_warn) and notify.sh. Isolated from the real network and
# from any real Telegram bot.
_notify_run() {

    PATH="${STUB_BIN}:${PATH}" PROJECT_ROOT="${PROJECT_ROOT}" \
        NOTIFICATIONS_ENABLED="${NOTIFICATIONS_ENABLED:-true}" \
        TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN-test-token}" \
        TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID-test-chat}" \
        NOTIFY_STUB_CURL_EXIT="${NOTIFY_STUB_CURL_EXIT:-0}" \
        bash -c '
            source "${PROJECT_ROOT}/lib/logger.sh"
            source "${PROJECT_ROOT}/lib/state.sh"
            source "${PROJECT_ROOT}/lib/metrics.sh"
            source "${PROJECT_ROOT}/lib/notify.sh"
            LOGGER_HANDLER_CONSOLE=false
            "$@"
        ' _notify_run "$@" >/dev/null 2>&1

}

# Same as _notify_run, but prints state_get "$1" after running "$@" (the
# notify_* call), so tests can check the metrics counters it recorded.
_notify_run_and_read_state() {

    local state_key="$1"
    shift

    PATH="${STUB_BIN}:${PATH}" PROJECT_ROOT="${PROJECT_ROOT}" \
        NOTIFICATIONS_ENABLED="${NOTIFICATIONS_ENABLED:-true}" \
        TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN-test-token}" \
        TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID-test-chat}" \
        NOTIFY_STUB_CURL_EXIT="${NOTIFY_STUB_CURL_EXIT:-0}" \
        STATE_KEY="${state_key}" \
        bash -c '
            source "${PROJECT_ROOT}/lib/logger.sh"
            source "${PROJECT_ROOT}/lib/state.sh"
            source "${PROJECT_ROOT}/lib/metrics.sh"
            source "${PROJECT_ROOT}/lib/notify.sh"
            LOGGER_HANDLER_CONSOLE=false
            "$@" >/dev/null 2>&1
            state_get "${STATE_KEY}"
        ' _notify_run_and_read_state "$@"

}

################################################################################
# Disabled notifications never call curl
################################################################################

rm -f "${CURL_LOG}"

NOTIFICATIONS_ENABLED=false _notify_run notify_info "test"

assert_false \
    "disabled notifications skip curl" \
    test -f "${CURL_LOG}"

################################################################################
# Missing bot token / chat id never calls curl
################################################################################

rm -f "${CURL_LOG}"

TELEGRAM_BOT_TOKEN="" _notify_run notify_info "test"

assert_false \
    "missing TELEGRAM_BOT_TOKEN skips curl" \
    test -f "${CURL_LOG}"

rm -f "${CURL_LOG}"

TELEGRAM_CHAT_ID="" _notify_run notify_info "test"

assert_false \
    "missing TELEGRAM_CHAT_ID skips curl" \
    test -f "${CURL_LOG}"

################################################################################
# Enabled + configured calls curl with the message, against the Telegram API
################################################################################

rm -f "${CURL_LOG}"

_notify_run notify_warning "power lost"

assert_true \
    "enabled notification calls curl" \
    test -f "${CURL_LOG}"

assert_true \
    "curl call carries the message" \
    grep -q "power lost" "${CURL_LOG}"

assert_true \
    "curl call targets the Telegram bot API with the token" \
    grep -q "api.telegram.org/bottest-token/sendMessage" "${CURL_LOG}"

assert_true \
    "curl call carries the chat id" \
    grep -q "chat_id=test-chat" "${CURL_LOG}"

assert_true \
    "warning uses the warning emoji" \
    grep -q "⚠️" "${CURL_LOG}"

################################################################################
# Metrics: a successful send increments notify_sent, a failure notify_failed
################################################################################

assert_equals \
    "a successful send increments metrics:notify_sent" \
    "1" \
    "$(_notify_run_and_read_state metrics:notify_sent notify_info "ok")"

assert_equals \
    "a failing send increments metrics:notify_failed" \
    "1" \
    "$(NOTIFY_STUB_CURL_EXIT=1 _notify_run_and_read_state metrics:notify_failed notify_info "boom")"

################################################################################
# Fail-safe: a curl failure never propagates
################################################################################

rm -f "${CURL_LOG}"

# Runs under set -e, as bootstrap.sh would, to prove a failing curl can't
# abort the caller.
OUTPUT="$(
    PATH="${STUB_BIN}:${PATH}" \
        PROJECT_ROOT="${PROJECT_ROOT}" \
        NOTIFICATIONS_ENABLED=true TELEGRAM_BOT_TOKEN=test-token TELEGRAM_CHAT_ID=test-chat \
        NOTIFY_STUB_CURL_EXIT=1 \
        bash -c '
            set -Eeuo pipefail
            source "${PROJECT_ROOT}/lib/logger.sh"
            source "${PROJECT_ROOT}/lib/state.sh"
            source "${PROJECT_ROOT}/lib/metrics.sh"
            source "${PROJECT_ROOT}/lib/notify.sh"
            LOGGER_HANDLER_CONSOLE=false
            notify_error "disk on fire"
            echo "survived"
        '
)"

assert_equals \
    "a failing curl under set -e does not abort the caller" \
    "survived" \
    "${OUTPUT}"

rm -rf "${STUB_BIN}" "${CURL_LOG}"

test_summary
