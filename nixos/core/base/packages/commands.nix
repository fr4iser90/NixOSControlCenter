{ config, lib, pkgs, getModuleApi, systemConfig ? null, ... }:
let
  cfg = lib.attrByPath ["core" "base" "packages"] {} systemConfig;
  cliRegistry = getModuleApi "cli-registry";

  packagesCli = pkgs.writeShellScriptBin "ncc-packages" ''
    #!/usr/bin/env bash
    set -euo pipefail

    SCRIPT_NAME="ncc-packages"
    VERSION="1.0.0"

    NIXOS_DIR="${NIXOS_DIR:-/etc/nixos}"
    SYSTEM_CONFIG="${NIXOS_DIR}/systemConfig"

    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'

    log_info()    { echo -e "${BLUE}[i]${NC} $*"; }
    log_success() { echo -e "${GREEN}[+]${NC} $*"; }
    log_warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
    log_error()   { echo -e "${RED}[-]${NC} $*" >&2; }

    COMMAND=""
    PACKAGE=""
    TARGET_USER=""
    TARGET_SYSTEM=false

    usage() {
        cat << EOF
${SCRIPT_NAME} - Package Management CLI

Usage:
  ${SCRIPT_NAME} add <package> [--user <name>] [--system]
  ${SCRIPT_NAME} remove <package> [--user <name>] [--system]
  ${SCRIPT_NAME} list [--system]

Commands:
  add       Add a package to the target
  remove    Remove a package from the target
  list      List all configured packages

Flags:
  --system       Target systemPackages (global, all users)
  --user <name>  Target a specific user's userPackages
  -h, --help     Show this help message
  -v, --version  Show version

Defaults:
  Without flags, operations target the current user's userPackages.

Examples:
  ncc packages add vscode                     # Add to current user
  ncc packages add nginx --system             # Add to system
  ncc packages add firefox --user alice       # Add to alice
  ncc packages remove vscode                  # Remove from current user
  ncc packages list                           # List all packages
  ncc packages list --system                  # List system packages only

EOF
        exit 0
    }

    version() {
        echo "${SCRIPT_NAME} ${VERSION}"
        exit 0
    }

    parse_args() {
        if [[ $# -eq 0 ]]; then
            usage
        fi

        COMMAND="$1"
        shift

        case "${COMMAND}" in
            add|remove|list) ;;
            -h|--help) usage ;;
            -v|--version) version ;;
            *)
                log_error "Unknown command: ${COMMAND}"
                echo "Valid commands: add, remove, list"
                exit 1
                ;;
        esac

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --system)
                    TARGET_SYSTEM=true
                    shift
                    ;;
                --user)
                    if [[ -z "${2:-}" ]]; then
                        log_error "--user requires a username argument"
                        exit 1
                    fi
                    TARGET_USER="$2"
                    shift 2
                    ;;
                -h|--help) usage ;;
                -v|--version) version ;;
                -*)
                    log_error "Unknown flag: $1"
                    exit 1
                    ;;
                *)
                    if [[ -z "${PACKAGE:-}" ]]; then
                        PACKAGE="$1"
                    else
                        log_error "Unexpected argument: $1"
                        exit 1
                    fi
                    shift
                    ;;
            esac
        done

        if [[ "${COMMAND}" != "list" ]] && [[ -z "${PACKAGE:-}" ]]; then
            log_error "Missing package name. Usage: ${SCRIPT_NAME} ${COMMAND} <package> [flags]"
            exit 1
        fi
    }

    resolve_target_user() {
        if [[ -n "${TARGET_USER:-}" ]]; then
            echo "${TARGET_USER}"
        else
            whoami 2>/dev/null || echo "root"
        fi
    }

    get_user_config_path() {
        echo "${SYSTEM_CONFIG}/users/$1/config.nix"
    }

    get_system_config_path() {
        echo "${SYSTEM_CONFIG}/core/base/packages/config.nix"
    }

    config_exists() {
        [[ -f "$1" ]]
    }

    ensure_dir() {
        mkdir -p "$(dirname "$1")"
    }

    package_in_config() {
        local config_path="$1"
        local package="$2"
        grep -qE "\"${package}\"|'${package}'" "${config_path}" 2>/dev/null
    }

    add_package() {
        local config_path="$1"
        local package="$2"
        local option_name="$3"

        if package_in_config "${config_path}" "${package}"; then
            log_warn "Package '${package}' already in config, skipping"
            return 0
        fi

        if ! config_exists "${config_path}"; then
            ensure_dir "${config_path}"
            cat > "${config_path}" << EOF
# Per-user package configuration
${option_name} = [ "${package}" ];
EOF
            log_success "Created config and added '${package}'"
            return 0
        fi

        if grep -qE "^${option_name}\s*=" "${config_path}" 2>/dev/null; then
            if grep -qE "^${option_name}\s*=\s*\[\]" "${config_path}" 2>/dev/null; then
                sed -i "s/^${option_name}\s*=\s*\[\]$/&\n  \"${package}\";/" "${config_path}"
            elif grep -qE "^${option_name}\s*=\s*\[.*\]" "${config_path}" 2>/dev/null; then
                sed -i "s/^\(${option_name}\s*=\s*\[.*\])$/\1\n  \"${package}\";/" "${config_path}"
            else
                local temp_file
                temp_file=$(mktemp)
                local in_array=false
                local found_option=false

                while IFS= read -r line; do
                    if echo "${line}" | grep -qE "^${option_name}\s*="; then
                        found_option=true
                        in_array=true
                        echo "${line}" >> "${temp_file}"
                    elif [[ "${found_option}" == true ]] && [[ "${in_array}" == true ]]; then
                        if echo "${line}" | grep -qE "^\s*\]"; then
                            printf '    "%s";\n' "${package}" >> "${temp_file}"
                            echo "${line}" >> "${temp_file}"
                            in_array=false
                            found_option=false
                        else
                            echo "${line}" >> "${temp_file}"
                        fi
                    else
                        echo "${line}" >> "${temp_file}"
                    fi
                done < "${config_path}"

                mv "${temp_file}" "${config_path}"
            fi
        else
            printf '\n%s = [ "%s" ];\n' "${option_name}" "${package}" >> "${config_path}"
        fi

        log_success "Added '${package}' to ${config_path}"
    }

    remove_package() {
        local config_path="$1"
        local package="$2"
        local option_name="$3"

        if ! config_exists "${config_path}"; then
            log_error "Config file not found: ${config_path}"
            exit 1
        fi

        if ! package_in_config "${config_path}" "${package}"; then
            log_error "Package '${package}' not found in ${config_path}"
            exit 1
        fi

        local temp_file
        temp_file=$(mktemp)
        local in_target=false
        local found_option=false

        while IFS= read -r line; do
            if echo "${line}" | grep -qE "^${option_name}\s*="; then
                found_option=true
                in_target=true
                echo "${line}" >> "${temp_file}"
            elif [[ "${found_option}" == true ]] && [[ "${in_target}" == true ]]; then
                if echo "${line}" | grep -qE "^\s*\]"; then
                    in_target=false
                    found_option=false
                    echo "${line}" >> "${temp_file}"
                elif echo "${line}" | grep -qE "^\s*\"?${package}\"?\s*(,|$)"; then
                    :
                else
                    echo "${line}" >> "${temp_file}"
                fi
            else
                echo "${line}" >> "${temp_file}"
            fi
        done < "${config_path}"

        mv "${temp_file}" "${config_path}"
        log_success "Removed '${package}' from ${config_path}"
    }

    list_packages_from_config() {
        local config_path="$1"
        local option_name="$2"
        local label="$3"

        if ! config_exists "${config_path}"; then
            return 0
        fi

        local in_option=false
        while IFS= read -r line; do
            if echo "${line}" | grep -qE "^${option_name}\s*="; then
                in_option=true
                echo "${label}:"
            elif [[ "${in_option}" == true ]]; then
                if echo "${line}" | grep -qE "^\s*\]"; then
                    in_option=false
                else
                    local pkg
                    pkg=$(echo "${line}" | sed -E "s/.*[\"']([^\"']+)[\"'].*/\1/")
                    if [[ -n "${pkg}" ]] && [[ "${pkg}" != "${option_name}" ]]; then
                        echo "  - ${pkg}"
                    fi
                fi
            fi
        done < "${config_path}"

        if [[ "${in_option}" == true ]]; then
            echo ""
        fi
    }

    main() {
        parse_args "$@"

        case "${COMMAND}" in
            add)
                local target_user
                target_user=$(resolve_target_user)

                if [[ "${TARGET_SYSTEM}" == true ]]; then
                    add_package "$(get_system_config_path)" "${PACKAGE}" "systemPackages"
                else
                    add_package "$(get_user_config_path "${target_user}")" "${PACKAGE}" "userPackages"
                fi
                ;;

            remove)
                local target_user
                target_user=$(resolve_target_user)

                if [[ "${TARGET_SYSTEM}" == true ]]; then
                    remove_package "$(get_system_config_path)" "${PACKAGE}" "systemPackages"
                else
                    remove_package "$(get_user_config_path "${target_user}")" "${PACKAGE}" "userPackages"
                fi
                ;;

            list)
                echo "=== NCC Package Configuration ==="
                echo ""

                if [[ "${TARGET_SYSTEM}" == true ]]; then
                    list_packages_from_config "$(get_system_config_path)" "systemPackages" "System Packages"
                else
                    local target_user
                    target_user=$(resolve_target_user)

                    local user_config_path
                    user_config_path=$(get_user_config_path "${target_user}")
                    list_packages_from_config "${user_config_path}" "userPackages" "User Packages (${target_user})"

                    local central_user_config="${SYSTEM_CONFIG}/core/base/user/config.nix"
                    if config_exists "${central_user_config}" && ! config_exists "${user_config_path}"; then
                        list_packages_from_config "${central_user_config}" "userPackages" "User Packages (central, ${target_user})"
                    fi

                    list_packages_from_config "$(get_system_config_path)" "systemPackages" "System Packages"
                fi
                ;;
        esac
    }

    main "$@"
  '';
in
{
  config = lib.mkIf (cfg.enable or true)
    (cliRegistry.registerCommandsFor "packages" [
      {
        name = "packages";
        domain = "packages";
        description = "Package management CLI";
        category = "base";
        script = "${packagesCli}/bin/ncc-packages";
        arguments = [];
        type = "manager";
        shortHelp = "packages - Package Management CLI";
        longHelp = ''
          Add, remove, and list packages for users and the system.

          Usage:
            ncc packages add <package> [--user <name>] [--system]
            ncc packages remove <package> [--user <name>] [--system]
            ncc packages list [--system]

          Defaults:
            - Without flags, operations target the current user's userPackages
            - --system targets systemPackages (global, all users)
            - --user <name> overrides the target user

          Examples:
            ncc packages add vscode                  # Add to current user
            ncc packages add nginx --system          # Add to system
            ncc packages add firefox --user alice    # Add to alice
            ncc packages list
        '';
      }
    ]);
}