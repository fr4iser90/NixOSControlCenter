#!/bin/bash

generate_salt() {
    generate_random_string 16
}

hash_password() {
    local password=$1
    local salt=$(generate_salt)
    nix-shell -p libargon2 --run "echo -n '$password' | argon2 '$salt' -id -t 2 -m 16 -p 1" | grep -Eo '\$argon2id\$[^\s]+'
}