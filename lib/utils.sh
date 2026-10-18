#!/usr/bin/env bash

################################################################################
# Command helpers
################################################################################

command_exists() {

    local command="$1"

    command -v "${command}" >/dev/null 2>&1

}

require_command() {

    local command

    for command in "$@"; do
        command_exists "${command}" || return 1
    done

    return 0

}

################################################################################
# Filesystem helpers
################################################################################

file_exists() {

    local file="$1"

    [[ -f "${file}" ]]

}

directory_exists() {

    local directory="$1"

    [[ -d "${directory}" ]]

}

ensure_directory() {

    local directory="$1"

    mkdir -p "${directory}"

}

################################################################################
# Time helpers
################################################################################

timestamp_now() {

    date '+%Y-%m-%d %H:%M:%S'

}

timestamp_iso8601() {

    date '+%Y-%m-%dT%H:%M:%S%z'

}

timestamp_epoch() {

    date +%s

}
