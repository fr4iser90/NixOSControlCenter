#!/usr/bin/env bash


sed -i '/profileModules = {/,/};/c\
  profileModules = {\
  };' "$CONFIG_FILE"