#!/usr/bin/env bash


sed -i '/profileModules = {/,/};/c\
  profileModules = {\
    gaming = {\
      streaming = true;\
      emulation = false;\
    };\
    development = {\
      game = true;\
      web = true;\
    };\
  };' "$CONFIG_FILE"