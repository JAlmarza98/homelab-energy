#!/bin/bash

LOG_FILE="/opt/homelab-energy/logs/energy.log"

log(){

    local level="$1"
    shift

    echo "$(date '+%F %T') [$level] $*" | tee -a "$LOG_FILE"

}
