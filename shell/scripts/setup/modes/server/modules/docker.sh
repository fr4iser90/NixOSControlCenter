#!/usr/bin/env bash

enable_docker() {
    sed -i '/server = {/,/};/s/docker = .*;/docker = true;/' "$SYSTEM_CONFIG_FILE"
}

reset_docker_state() {
    sed -i '/server = {/,/};/s/docker = .*;/docker = false;/' "$SYSTEM_CONFIG_FILE"
}