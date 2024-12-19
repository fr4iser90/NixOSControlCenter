#!/usr/bin/env bash

# Setze Berechtigungen für alle Skripte
echo "Setting execute permissions for scripts..."
chmod +x $INSTALL_SCRIPTS/checks/hardware/*.sh
chmod +x $INSTALL_SCRIPTS/checks/system/*.sh
chmod +x $INSTALL_SCRIPTS/setup/modes/*.sh
chmod +x $INSTALL_SCRIPTS/lib/prompts/*.sh
chmod +x $INSTALL_SCRIPTS/lib/*.sh
chmod +x $INSTALL_SCRIPTS/*.sh
