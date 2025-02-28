#!/bin/bash

generate_random_string() {
    nix-shell -p openssl --run "openssl rand -base64 ${1:-32}"
}

escape_for_sed() {
    echo "$1" | sed -e 's/[\/&]/\\&/g'
}