#!/usr/bin/env bash

################################################################################
# Core
################################################################################

# Never makes shutdown decisions: upsmon/upssched already own that. This
# module only reads upsc, read-only, so it can never issue a cutoff.
_nut_target() {

    printf '%s@%s' "${UPS_NAME:-ups}" "${NUT_SERVER:-localhost}"

}

_nut_query() {

    local variable="$1"

    upsc "$(_nut_target)" "${variable}"

}

################################################################################
# Public API
################################################################################

nut_get_status() {

    _nut_query ups.status

}

nut_get_charge() {

    _nut_query battery.charge

}

nut_get_runtime() {

    _nut_query battery.runtime

}

nut_get_voltage() {

    _nut_query input.voltage

}

nut_get_load() {

    _nut_query ups.load

}

nut_is_online() {

    local status

    status="$(nut_get_status)" || return 1

    [[ "${status}" == *OL* ]]

}

nut_is_on_battery() {

    local status

    status="$(nut_get_status)" || return 1

    [[ "${status}" == *OB* ]]

}

nut_is_charging() {

    local status

    status="$(nut_get_status)" || return 1

    [[ "${status}" == *CHRG* ]]

}
