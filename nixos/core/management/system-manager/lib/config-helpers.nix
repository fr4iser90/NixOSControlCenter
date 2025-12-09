{ pkgs, lib, backupHelpers }:

let
  setupConfigFile = symlinkPath: userConfigFilePath: defaultConfig: ''
    mkdir -p "$(dirname "${symlinkPath}")"
    mkdir -p "$(dirname "${userConfigFilePath}")"

    if [ ! -f "${userConfigFilePath}" ]; then
      cat << 'EOF' > "${userConfigFilePath}"
${defaultConfig}
EOF
      chmod 644 "${userConfigFilePath}"
    fi

    if [ ! -f "${symlinkPath}" ]; then
      ln -s "${userConfigFilePath}" "${symlinkPath}"
    fi
  '';
in
{
  inherit setupConfigFile;
}
