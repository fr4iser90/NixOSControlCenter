#!/usr/bin/env bash

reset_database_state() {
    sed -i '/server = {/,/};/s/database = .*;/database = false;/' "$SYSTEM_CONFIG_FILE"
}

enable_database() {
    sed -i '/server = {/,/};/s/database = .*;/database = true;/' "$SYSTEM_CONFIG_FILE"
}

export -f reset_database_state
export -f enable_database