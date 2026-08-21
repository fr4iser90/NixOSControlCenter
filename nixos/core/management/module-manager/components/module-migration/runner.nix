{ pkgs, lib, getModuleApi, getModuleMetadata }:

let
  ui = getModuleApi "cli-formatter";
  plans = (import ./plans.nix { inherit lib; }).plans;
  plansJson = builtins.toJSON plans;
  smRoot = (getModuleMetadata "system-manager").path;
  facade = import "${smRoot}/lib/config-facade.nix" { inherit pkgs; };
  backupHelpers = import "${smRoot}/lib/backup-helpers.nix" { inherit pkgs lib; };
  discoveryPkg = import ../../lib/runtime_discovery.nix { inherit lib pkgs; };
  discoverBin = "${discoveryPkg.discoveryBin}/bin/ncc-modules-discover";

  moduleMigrate = pkgs.writeShellScriptBin "ncc-module-migrate" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    DRY=0
    VERBOSE=0
    SKIP_ORPHANS=0
    for a in "$@"; do
      case "$a" in
        --dry-run) DRY=1 ;;
        --verbose|-v) VERBOSE=1 ;;
        --skip-orphans) SKIP_ORPHANS=1 ;;
        -h|--help)
          cat <<EOF
ncc-module-migrate — migrate / clean legacy module configs

Runs module migration plans (renames, merges) then orphan cleanup
under systemConfig/{core,modules} (split layout). Never touches:
  - \$NIXOS_ROOT/custom/     (userspace NixOS modules)
  - systemConfig/custom/     (if present)

Monolith: module + user config live only in systemConfig.nix;
migration state is /var/lib/ncc/module-migrations.json (not under /etc/nixos).

Idempotent; state: /var/lib/ncc/module-migrations.json
  (legacy: \$NIXOS_ROOT/systemConfig/.ncc-module-migrations.json — migrated automatically)

Usage:
  ncc modules migrate [--dry-run] [--verbose] [--skip-orphans]
  ncc-module-migrate […]
EOF
          exit 0
          ;;
      esac
    done

    ${facade.sourcePreamble { nixosRoot = "/etc/nixos"; }}

    ${backupHelpers.backupConfigFileFn}

    PLANS_JSON='${plansJson}'
    NCC_STATE_DIR="''${NCC_STATE_DIR:-/var/lib/ncc}"
    STATE_FILE="$NCC_STATE_DIR/module-migrations.json"
    LEGACY_STATE="''${CONFIGS_BASE}/.ncc-module-migrations.json"
    mkdir -p "$NCC_STATE_DIR" 2>/dev/null || sudo mkdir -p "$NCC_STATE_DIR"
    # One-time move from hybrid path under /etc/nixos
    if [[ -f "$LEGACY_STATE" && ! -f "$STATE_FILE" ]]; then
      cp -a "$LEGACY_STATE" "$STATE_FILE" 2>/dev/null || sudo cp -a "$LEGACY_STATE" "$STATE_FILE"
      rm -f "$LEGACY_STATE" 2>/dev/null || sudo rm -f "$LEGACY_STATE"
    fi

    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      if [[ "$DRY" -eq 1 ]]; then
        ${ui.text.header "Module migrate (dry-run)"}
        ${ui.messages.info "Preview only — nothing will be written under $NIXOS_ROOT"}
      else
        ${ui.text.header "Module migrate"}
      fi
    fi

    if [[ -f "$STATE_FILE" ]]; then
      APPLIED=$(${pkgs.jq}/bin/jq -c '.applied // []' "$STATE_FILE" 2>/dev/null || echo '[]')
    else
      APPLIED='[]'
    fi

    log() { [[ "$VERBOSE" -eq 1 ]] && echo "$*" >&2 || true; }

    path_exists() {
      local p="$1"
      local layout
      layout=$(ncc_detect_layout)
      case "$layout" in
        split)
          [[ -f "$(ncc_module_config_path "$p")" ]]
          ;;
        monolith)
          [[ -f "$MONOLITH_FILE" ]] || return 1
          local path_json json
          path_json=$(_ncc_path_to_jq_array "$p")
          json=$("$NIX_INSTANTIATE_BIN" --eval --strict --json -E "import $MONOLITH_FILE" 2>/dev/null) || return 1
          echo "$json" | ${pkgs.jq}/bin/jq -e --argjson path "$path_json" '
            try (getpath($path) | type == "object") catch false
          ' >/dev/null 2>&1
          ;;
        *) return 1 ;;
      esac
    }

    read_leaf_json() {
      local p="$1"
      local nix_txt
      nix_txt=$(ncc_read_module_config "$p" 2>/dev/null || echo "{}")
      if [[ -z "$nix_txt" || "$nix_txt" == "{}" ]]; then
        echo '{}'
        return 0
      fi
      _ncc_eval_nix_to_json "$nix_txt" 2>/dev/null || echo '{}'
    }

    write_leaf_json() {
      local p="$1"
      local json="$2"
      local tmp nix_out cleaned
      # User systemConfig must stay lean — migration state lives in
      # /var/lib/ncc/module-migrations.json, not in leaf attrs.
      cleaned=$(echo "$json" | ${pkgs.jq}/bin/jq -c '
        del(._migratedFrom, ._version, ._dependencies, ._conflicts)
      ') || cleaned="$json"
      tmp=$(mktemp --suffix=.json)
      printf '%s\n' "$cleaned" > "$tmp"
      nix_out=$(_ncc_json_to_nix "$tmp") || { rm -f "$tmp"; return 1; }
      rm -f "$tmp"
      ncc_write_module_config "$p" "$nix_out"
    }

    delete_leaf() {
      local p="$1"
      local layout
      layout=$(ncc_detect_layout)
      case "$layout" in
        split)
          local f
          f=$(ncc_module_config_path "$p")
          if [[ -f "$f" ]]; then
            rm -f "$f" 2>/dev/null || sudo rm -f "$f"
            # remove empty parents up to security/
            rmdir "$(dirname "$f")" 2>/dev/null || true
          fi
          ;;
        monolith)
          [[ -f "$MONOLITH_FILE" ]] || return 0
          local path_json json merged tmp
          path_json=$(_ncc_path_to_jq_array "$p")
          json=$("$NIX_INSTANTIATE_BIN" --eval --strict --json -E "import $MONOLITH_FILE" 2>/dev/null) || return 0
          merged=$(echo "$json" | ${pkgs.jq}/bin/jq -c --argjson path "$path_json" 'delpaths([$path])')
          tmp=$(mktemp --suffix=.json)
          printf '%s\n' "$merged" > "$tmp"
          _ncc_write_monolith_json "$tmp"
          rm -f "$tmp"
          ;;
      esac
    }

    # Strip migration/engine meta that must not live in user systemConfig leaves.
    # Applied state: /var/lib/ncc/module-migrations.json only.
    strip_leaf_internal_meta() {
      local p="$1"
      local j cleaned
      path_exists "$p" || return 0
      j=$(read_leaf_json "$p")
      cleaned=$(echo "$j" | ${pkgs.jq}/bin/jq -c '
        del(._migratedFrom, ._version, ._dependencies, ._conflicts)
      ')
      if [[ "$j" == "$cleaned" ]]; then
        return 0
      fi
      if [[ "$DRY" -eq 1 ]]; then
        log "would strip internal meta from $p"
        return 0
      fi
      ${ui.messages.loading "Cleaning internal meta from $p"}
      write_leaf_json "$p" "$cleaned" || true
    }

    strip_known_leaves_internal_meta() {
      strip_leaf_internal_meta "modules/infrastructure/stack-manager"
      strip_leaf_internal_meta "modules/security/ssh-manager"
    }

    mark_applied() {
      local id="$1"
      local tmp
      tmp=$(mktemp)
      echo "$APPLIED" | ${pkgs.jq}/bin/jq -c --arg id "$id" '
        . as $a | if ($a | index($id)) then $a else ($a + [$id]) end
      ' > "$tmp.applied"
      APPLIED=$(cat "$tmp.applied")
      ${pkgs.jq}/bin/jq -n --argjson applied "$APPLIED" \
        '{applied: $applied, updated: (now | todate)}' > "$tmp"
      if [[ "$DRY" -eq 1 ]]; then
        rm -f "$tmp" "$tmp.applied"
        return 0
      fi
      if [[ "''${EUID:-$(id -u)}" -ne 0 ]]; then
        ${ui.messages.error "Writing migration state needs root (sudo)"}
        rm -f "$tmp" "$tmp.applied"
        return 1
      fi
      cp "$tmp" "$STATE_FILE"
      chmod 644 "$STATE_FILE" 2>/dev/null || true
      rm -f "$tmp" "$tmp.applied"
    }

    already_applied() {
      local id="$1"
      echo "$APPLIED" | ${pkgs.jq}/bin/jq -e --arg id "$id" 'index($id) != null' >/dev/null 2>&1
    }

    apply_ssh_merge() {
      local id="$1" to_path="$2"
      local server_p="modules/security/ssh-server-manager"
      local client_p="modules/security/ssh-client-manager"
      local client_spec_p="modules/specialized/ssh-client-manager"
      local has_s=0 has_c=0 has_cs=0 has_t=0
      local has_code=0

      path_exists "$server_p" && has_s=1
      path_exists "$client_p" && has_c=1
      path_exists "$client_spec_p" && has_cs=1
      path_exists "$to_path" && has_t=1
      [[ -d "$NIXOS_ROOT/$server_p" || -d "$NIXOS_ROOT/$client_p" ]] && has_code=1

      remove_legacy_ssh_code() {
        if [[ "$DRY" -eq 1 ]]; then
          for p in "$server_p" "$client_p"; do
            [[ -d "$NIXOS_ROOT/$p" ]] && echo "  dry-run: would remove $NIXOS_ROOT/$p"
          done
          return 0
        fi
        for p in "$server_p" "$client_p"; do
          local legacy_code="$NIXOS_ROOT/$p"
          if [[ -d "$legacy_code" ]]; then
            ${ui.messages.warning "Removing leftover module tree: $legacy_code"}
            rm -rf "$legacy_code" 2>/dev/null || sudo rm -rf "$legacy_code"
          fi
        done
      }

      drop_specialized_ssh_client_leaf() {
        path_exists "$client_spec_p" || return 0
        if [[ "$DRY" -eq 1 ]]; then
          ${ui.messages.info "Would remove orphan leaf $client_spec_p"}
          return 0
        fi
        ${ui.messages.loading "Removing leftover $client_spec_p"}
        local sf
        sf=$(ncc_module_config_path "$client_spec_p")
        [[ -f "$sf" ]] && ncc_backup_config_file "$sf" "module-migrate-ssh-orphan" >/dev/null 2>&1 || true
        delete_leaf "$client_spec_p"
      }

      if [[ "$has_s" -eq 0 && "$has_c" -eq 0 && "$has_cs" -eq 0 ]]; then
        if [[ "$has_code" -eq 1 ]]; then
          ${ui.messages.loading "Plan $id: configs already merged — removing leftover module trees"}
          remove_legacy_ssh_code
          mark_applied "$id"
          ${ui.messages.success "Legacy SSH module trees removed"}
          return 0
        fi
        log "ssh-merge: no legacy leaves — skip"
        if [[ "$has_t" -eq 1 ]] || already_applied "$id"; then
          mark_applied "$id" || true
        fi
        return 0
      fi

      # Only specialized orphan left (common after earlier security-path merge)
      if [[ "$has_s" -eq 0 && "$has_c" -eq 0 && "$has_cs" -eq 1 ]]; then
        ${ui.messages.loading "Plan $id: removing specialized ssh-client-manager orphan"}
        if [[ "$has_t" -eq 1 && "$DRY" -eq 0 ]]; then
          local spec_j tgt_j folded
          spec_j=$(read_leaf_json "$client_spec_p")
          tgt_j=$(read_leaf_json "$to_path")
          folded=$(${pkgs.jq}/bin/jq -nc --argjson s "$spec_j" --argjson t "$tgt_j" '
            ($t.client // {}) as $cli |
            ($s | del(.enable, ._version, ._dependencies, ._conflicts, ._migratedFrom)) as $spec |
            $t + {
              client: (
                $cli + $spec + {
                  enable: ($cli.enable // $spec.enable // false),
                  connections: (($cli.connections // {}) + ($spec.connections // {})),
                  settings: (($cli.settings // {}) + ($spec.settings // {}))
                }
              )
            }
            | del(._migratedFrom, ._version, ._dependencies, ._conflicts)
          ')
          write_leaf_json "$to_path" "$folded" || true
        fi
        drop_specialized_ssh_client_leaf
        mark_applied "$id"
        ${ui.messages.success "Removed specialized ssh-client-manager orphan"}
        return 0
      fi

      ${ui.messages.loading "Plan $id: merge SSH server/client → ssh-manager"}
      if [[ "$VERBOSE" -eq 1 ]]; then
        echo "  legacy server config: $([[ $has_s -eq 1 ]] && echo yes || echo no)"
        echo "  legacy client (security): $([[ $has_c -eq 1 ]] && echo yes || echo no)"
        echo "  legacy client (specialized): $([[ $has_cs -eq 1 ]] && echo yes || echo no)"
        echo "  target ssh-manager:   $([[ $has_t -eq 1 ]] && echo exists || echo new)"
      fi

      local server_j client_j target_j merged
      local has_c_eff=0
      [[ "$has_c" -eq 1 || "$has_cs" -eq 1 ]] && has_c_eff=1
      server_j=$([[ "$has_s" -eq 1 ]] && read_leaf_json "$server_p" || echo '{}')
      if [[ "$has_c" -eq 1 && "$has_cs" -eq 1 ]]; then
        client_j=$(${pkgs.jq}/bin/jq -nc \
          --argjson a "$(read_leaf_json "$client_p")" \
          --argjson b "$(read_leaf_json "$client_spec_p")" \
          '$a * $b')
      elif [[ "$has_c" -eq 1 ]]; then
        client_j=$(read_leaf_json "$client_p")
      elif [[ "$has_cs" -eq 1 ]]; then
        client_j=$(read_leaf_json "$client_spec_p")
      else
        client_j='{}'
      fi
      target_j=$([[ "$has_t" -eq 1 ]] && read_leaf_json "$to_path" || echo '{}')

      merged=$(${pkgs.jq}/bin/jq -nc \
        --argjson s "$server_j" \
        --argjson c "$client_j" \
        --argjson t "$target_j" \
        --argjson has_s "$has_s" \
        --argjson has_c "$has_c_eff" '
        def as_bool($x; $d): if $x == null then $d else $x end;
        ($t // {}) as $base |
        ($s // {}) as $srv |
        ($c // {}) as $cli |
        (if $has_c == 1 then
            (($cli | del(.enable) | del(._version) | del(._dependencies) | del(._conflicts) | del(._migratedFrom))
              + { enable: as_bool($cli.enable; false) })
          else ($base.client // { enable: false }) end) as $client_obj |
        ($base + $srv + {
          enable: (if $has_s == 1 then as_bool($srv.enable; false)
                   else as_bool($base.enable; false) end),
          passwordAuthentication: as_bool($srv.passwordAuthentication // $base.passwordAuthentication; true),
          permitRootLogin: ($srv.permitRootLogin // $base.permitRootLogin // "yes"),
          workflow: ($srv.workflow // $base.workflow // { enable: false }),
          client: $client_obj,
          banner: ($srv.banner // $base.banner // null)
        } | with_entries(select(.value != null))
          | del(._migratedFrom, ._version, ._dependencies, ._conflicts))
      ')

      if [[ "$VERBOSE" -eq 1 ]]; then
        echo "  merged preview:"
        echo "$merged" | ${pkgs.jq}/bin/jq -C '.' 2>/dev/null | sed 's/^/    /' || echo "$merged" | sed 's/^/    /'
      fi

      if [[ "$DRY" -eq 1 ]]; then
        ${ui.messages.info "Would merge SSH configs (dry-run) — no changes written"}
        return 0
      fi

      if [[ "''${EUID:-$(id -u)}" -ne 0 ]]; then
        ${ui.messages.error "Apply needs root: sudo ncc module migrate"}
        return 1
      fi

      # Backup
      if [[ -f "$MONOLITH_FILE" ]]; then
        ncc_backup_config_file "$MONOLITH_FILE" "module-migrate-ssh" >/dev/null 2>&1 || true
      fi
      if [[ "$has_s" -eq 1 ]]; then
        local sf
        sf=$(ncc_module_config_path "$server_p")
        [[ -f "$sf" ]] && ncc_backup_config_file "$sf" "module-migrate-ssh" >/dev/null 2>&1 || true
      fi
      if [[ "$has_c" -eq 1 ]]; then
        local cf
        cf=$(ncc_module_config_path "$client_p")
        [[ -f "$cf" ]] && ncc_backup_config_file "$cf" "module-migrate-ssh" >/dev/null 2>&1 || true
      fi
      if [[ "$has_cs" -eq 1 ]]; then
        local csf
        csf=$(ncc_module_config_path "$client_spec_p")
        [[ -f "$csf" ]] && ncc_backup_config_file "$csf" "module-migrate-ssh" >/dev/null 2>&1 || true
      fi

      write_leaf_json "$to_path" "$merged" || {
        ${ui.messages.error "Failed to write $to_path"}
        return 1
      }
      delete_leaf "$server_p"
      delete_leaf "$client_p"
      drop_specialized_ssh_client_leaf
      remove_legacy_ssh_code
      mark_applied "$id"
      ${ui.messages.success "Migrated → $to_path (legacy SSH module configs removed)"}
    }

    # Simple rename: copy leaf config fromPaths[0] → toPath, delete old leaf + code tree
    apply_rename() {
      local id="$1" plan="$2"
      local from_p to_p
      from_p=$(echo "$plan" | ${pkgs.jq}/bin/jq -r '.fromPaths[0] // empty')
      to_p=$(echo "$plan" | ${pkgs.jq}/bin/jq -r '.toPath // empty')
      if [[ -z "$from_p" || -z "$to_p" ]]; then
        ${ui.messages.error "rename plan $id missing fromPaths/toPath"}
        return 1
      fi

      local has_from=0 has_to=0 has_code=0
      path_exists "$from_p" && has_from=1
      path_exists "$to_p" && has_to=1
      [[ -d "$NIXOS_ROOT/$from_p" ]] && has_code=1

      if [[ "$has_from" -eq 0 && "$has_code" -eq 0 ]]; then
        log "rename $id: nothing to do"
        if [[ "$has_to" -eq 1 ]] || already_applied "$id"; then
          mark_applied "$id" || true
        fi
        return 0
      fi

      ${ui.messages.loading "Plan $id: rename $from_p → $to_p"}

      if [[ "$has_from" -eq 1 ]]; then
        local src_j tgt_j merged
        src_j=$(read_leaf_json "$from_p")
        tgt_j=$([[ "$has_to" -eq 1 ]] && read_leaf_json "$to_p" || echo '{}')
        merged=$(${pkgs.jq}/bin/jq -nc --argjson s "$src_j" --argjson t "$tgt_j" '
          ($t + $s)
          | del(._migratedFrom, ._version, ._dependencies, ._conflicts)
        ')
        if [[ "$VERBOSE" -eq 1 ]]; then
          echo "  preview:"
          echo "$merged" | ${pkgs.jq}/bin/jq -C '.' 2>/dev/null | sed 's/^/    /' || true
        fi
        if [[ "$DRY" -eq 1 ]]; then
          ${ui.messages.info "Would rename (dry-run) — no changes written"}
          return 0
        fi
        local sf
        sf=$(ncc_module_config_path "$from_p")
        [[ -f "$sf" ]] && ncc_backup_config_file "$sf" "module-migrate-rename" >/dev/null 2>&1 || true
        write_leaf_json "$to_p" "$merged" || {
          ${ui.messages.error "Failed to write $to_p"}
          return 1
        }
        delete_leaf "$from_p"
      elif [[ "$DRY" -eq 1 ]]; then
        ${ui.messages.info "Would remove leftover module tree (dry-run)"}
        [[ "$VERBOSE" -eq 1 ]] && ${ui.messages.info "Path: $NIXOS_ROOT/$from_p"}
        return 0
      fi

      if [[ -d "$NIXOS_ROOT/$from_p" ]]; then
        ${ui.messages.warning "Removing leftover module tree"}
        [[ "$VERBOSE" -eq 1 ]] && ${ui.messages.info "Path: $NIXOS_ROOT/$from_p"}
        rm -rf "$NIXOS_ROOT/$from_p" 2>/dev/null || sudo rm -rf "$NIXOS_ROOT/$from_p"
      fi

      mark_applied "$id"
      ${ui.messages.success "Renamed → $to_p"}
    }

    # --- Orphan cleanup (systemConfig leaves without a discovered module) ---
    # Never touch: custom/ (repo userspace), systemConfig/users/, systemConfig/custom/
    cleanup_orphans() {
      ${ui.messages.loading "Scanning for orphan module configs…"}
      local allowed tmp disc
      tmp=$(mktemp)
      disc=$(mktemp)
      if ! ${discoverBin} >"$disc" 2>/dev/null; then
        ${ui.messages.warning "Module discovery failed — skip orphan cleanup"}
        rm -f "$tmp" "$disc"
        return 0
      fi

      # Allowed relative paths: scope/rel (e.g. modules/security/ssh-manager)
      ${pkgs.jq}/bin/jq -r --arg base "$NIXOS_ROOT" '
        .[] |
        (.scope // "") as $s |
        (.path // "") as $p |
        select($s != "" and $p != "") |
        ($p | sub("^"+$base+"/"+$s+"/"; "")) |
        select(length > 0) |
        ($s + "/" + .)
      ' "$disc" > "$tmp.allowed" 2>/dev/null || true

      # Also accept bare module basenames colliding is rare; primary key is full rel path
      local orphans=0 removed=0
      local layout
      layout=$(ncc_detect_layout)

      if [[ "$layout" == "split" || -d "$CONFIGS_BASE/core" || -d "$CONFIGS_BASE/modules" ]]; then
        while IFS= read -r -d $'\0' cf; do
          # Absolute safety: never under custom or users
          case "$cf" in
            */custom/*|*/users/*) continue ;;
          esac
          local rel="''${cf#"$CONFIGS_BASE"/}"
          rel="''${rel%/config.nix}"
          case "$rel" in
            custom|/*/custom/*|users|/*/users/*) continue ;;
            core/*|modules/*) ;;
            *) continue ;; # only manage core/ + modules/ trees
          esac
          if grep -Fxq "$rel" "$tmp.allowed" 2>/dev/null; then
            continue
          fi
          orphans=$((orphans + 1))
          echo "  orphan: $rel"
          if [[ "$DRY" -eq 1 ]]; then
            continue
          fi
          if [[ "''${EUID:-$(id -u)}" -ne 0 ]]; then
            ${ui.messages.error "Orphan cleanup needs root: sudo ncc modules migrate"}
            rm -f "$tmp" "$tmp.allowed" "$disc"
            return 1
          fi
          ncc_backup_config_file "$cf" "module-orphan-cleanup" >/dev/null 2>&1 || true
          rm -f "$cf" 2>/dev/null || sudo rm -f "$cf"
          rmdir "$(dirname "$cf")" 2>/dev/null || true
          removed=$((removed + 1))
        done < <(find "$CONFIGS_BASE/core" "$CONFIGS_BASE/modules" \
          -name config.nix -type f -print0 2>/dev/null || true)
      fi

      # Monolith: named plans already delete legacy leaves. Generic deep-walk is unsafe
      # (nested enable like client.enable would look like orphans). Split layout only.
      if [[ "$layout" == "monolith" ]]; then
        log "monolith layout: generic orphan scan skipped (named plans cover renames; custom/ untouched)"
      fi

      rm -f "$tmp" "$tmp.allowed" "$disc"
      if [[ "$orphans" -eq 0 ]]; then
        ${ui.messages.success "No orphan module configs"}
      elif [[ "$DRY" -eq 1 ]]; then
        ${ui.messages.info "Dry-run: $orphans orphan config(s) would be removed (custom/ + users/ kept)"}
      else
        ${ui.messages.success "Removed $removed orphan module config(s)"}
      fi
    }

    ${ui.messages.loading "Scanning module migration plans…"}
    if [[ "$VERBOSE" -eq 1 ]]; then
      ${ui.tables.keyValue "Layout" "$(ncc_detect_layout)"}
    fi
    PENDING=0
    FAILED=0

    while IFS= read -r plan; do
      id=$(echo "$plan" | ${pkgs.jq}/bin/jq -r '.id')
      kind=$(echo "$plan" | ${pkgs.jq}/bin/jq -r '.kind // "generic"')
      desc=$(echo "$plan" | ${pkgs.jq}/bin/jq -r '.description')
      to_path=$(echo "$plan" | ${pkgs.jq}/bin/jq -r '.toPath // empty')

      if already_applied "$id"; then
        need=0
        while IFS= read -r fp; do
          [[ -z "$fp" || "$fp" == "null" ]] && continue
          path_exists "$fp" && need=1
          # Config may already be merged while module *code* tree still lingers
          [[ -d "$NIXOS_ROOT/$fp" ]] && need=1
        done < <(echo "$plan" | ${pkgs.jq}/bin/jq -r '.fromPaths[]?')
        if [[ "$need" -eq 0 ]]; then
          log "already applied: $id"
          continue
        fi
        ${ui.messages.info "Re-applying $id (legacy paths still present)"}
      fi

      case "$kind" in
        ssh-merge)
          PENDING=$((PENDING + 1))
          if ! apply_ssh_merge "$id" "$to_path"; then
            FAILED=$((FAILED + 1))
          fi
          ;;
        rename)
          PENDING=$((PENDING + 1))
          if ! apply_rename "$id" "$plan"; then
            FAILED=$((FAILED + 1))
          fi
          ;;
        *)
          ${ui.messages.warning "Unknown migration plan — skipped"}
          [[ "$VERBOSE" -eq 1 ]] && ${ui.messages.info "kind=$kind id=$id"}
          ;;
      esac
    done < <(echo "$PLANS_JSON" | ${pkgs.jq}/bin/jq -c '.[]')

    if [[ "$FAILED" -gt 0 ]]; then
      ${ui.messages.error "$FAILED module migration(s) failed"}
      exit 1
    elif [[ "$PENDING" -eq 0 ]]; then
      ${ui.messages.success "No pending named module migrations"}
    elif [[ "$DRY" -eq 1 ]]; then
      ${ui.messages.info "Dry-run: $PENDING plan(s) would run"}
    else
      ${ui.messages.success "Named module migrations complete"}
    fi

    if [[ "$SKIP_ORPHANS" -eq 0 ]]; then
      cleanup_orphans || exit 1
    else
      log "skipping orphan cleanup (--skip-orphans)"
    fi

    # Drop leftover _migratedFrom / _version from leaves (user systemConfig stays lean)
    strip_known_leaves_internal_meta

    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      if [[ "$DRY" -eq 1 ]]; then
        ${ui.messages.success "Dry-run migrate finished"}
        ${ui.messages.info "Next: sudo ncc modules migrate"}
      else
        ${ui.messages.success "Module migrate finished"}
      fi
    fi
  '';
in {
  inherit moduleMigrate;
  plans = plans;
}
