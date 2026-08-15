#!/bin/bash
# JSON export of wizard catalog for the Go TUI (and tests)

export_wizard_catalog() {
    PKG_MGR="${PKG_MGR_FLAG:-${PKG_MGR:-$(default_pkgmgr)}}"
    load_setup_prefs 2>/dev/null || true

    local active_id
    active_id="$(profile_resolve_id)"
    if ! profile_load "$active_id" 2>/dev/null; then
        active_id="$(profiles_list | head -n 1)"
        [[ -n "$active_id" ]] || {
            echo '{"error":"no profiles found under profiles/"}' >&2
            return 1
        }
        profile_load "$active_id" || return 1
    fi

    migrate_detect 2>/dev/null || true

    local platform_label_str
    platform_label_str="$(platform_label 2>/dev/null || echo "${PLATFORM:-unknown}")"

    if ! command -v python3 >/dev/null 2>&1; then
        echo '{"error":"python3 required for export_wizard_catalog"}' >&2
        return 1
    fi

    local missing_git=0 missing_curl=0
    command -v git >/dev/null 2>&1 || missing_git=1
    command -v curl >/dev/null 2>&1 || missing_curl=1

    {
        echo "meta	${PLATFORM:-}	${platform_label_str}	${PKG_MGR}	${DOTFILES_DIR:-}	${DRY_RUN:-}	${PROFILE_ID}	${PROFILE_NAME}	${PROFILE_DESCRIPTION}	${THEME_STARSHIP:-stock}	${MIGRATE_NEEDED:-}	${missing_git}	${missing_curl}"

        local pid pname pdesc
        while IFS=$'\t' read -r pid pname pdesc; do
            [[ -z "$pid" ]] && continue
            local is_default=0
            [[ "$pid" == "$active_id" ]] && is_default=1
            # Load profile for package lists + themes
            if ! profile_load "$pid" 2>/dev/null; then
                continue
            fi
            local theme="${THEME_STARSHIP:-stock}"
            printf 'profile\t%s\t%s\t%s\t%s\t%s\n' "$pid" "$pname" "$pdesc" "$is_default" "$theme"

            local id name desc category group gen_only
            for id in $(my_setup_ids); do
                catalog_available "$id" || continue
                name="$(catalog_get "$id" name)"
                desc="$(catalog_get "$id" description)"
                category="$(catalog_get "$id" category)"
                gen_only="$(catalog_get "$id" generate_only)"
                group="dev"
                case "$category" in
                    shells|shell-configs) group="shell" ;;
                    fonts) group="dev" ;;
                    *) group="dev" ;;
                esac
                # Prefer profile shell/dev split when available
                if [[ " $PROFILE_PACKAGES_SHELL " == *" $id "* ]]; then
                    group="shell"
                elif [[ " $PROFILE_PACKAGES_DEV " == *" $id "* ]]; then
                    group="dev"
                fi
                printf 'profile_pkg\t%s\t%s\t%s\t%s\t%s\t1\t%s\t%s\n' \
                    "$pid" "$id" "$name" "$desc" "$category" "$group" "${gen_only:-false}"
            done
        done < <(profiles_meta_tsv)

        # Active / full brew-first catalog (shell + all picker apps)
        profile_load "$active_id" || true
        local id name desc category group gen_only is_def
        local exported=" "
        for id in $(shell_ids_available) $(app_ids_all); do
            [[ "$exported" == *" $id "* ]] && continue
            exported+=" $id "
            catalog_available "$id" || continue
            [[ "$id" == "oh_my_zsh" ]] && continue
            name="$(catalog_get "$id" name)"
            desc="$(catalog_get "$id" description)"
            category="$(catalog_get "$id" category)"
            gen_only="$(catalog_get "$id" generate_only)"
            group="dev"
            case "$category" in
                shells|shell-configs) group="shell" ;;
                browsers) group="dev" ;;
                cli-tools) group="dev" ;;
                apps) group="dev" ;;
            esac
            is_def=0
            if catalog_is_default "$id" 2>/dev/null || [[ " $SHELL_IDS $APP_DEFAULT_IDS " == *" $id "* ]]; then
                is_def=1
            fi
            printf 'pkg\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                "$id" "$name" "$desc" "$category" "$is_def" "$group" "${gen_only:-false}"
        done

        echo "pkgmgr_opt	brew	Homebrew (brew)	1"
        true
    } | python3 -c '
import json, sys

doc = {
    "platform": "",
    "platform_label": "",
    "pkgmgr": "",
    "dotfiles_dir": "",
    "dry_run": False,
    "active_profile": "",
    "profile_name": "",
    "profile_description": "",
    "theme_starship": "stock",
    "migrate_needed": False,
    "missing_git": False,
    "missing_curl": False,
    "packages": [],
    "profiles": [],
    "pkgmgr_options": [],
}

profiles_by_id = {}

for line in sys.stdin:
    line = line.rstrip("\n")
    if not line:
        continue
    parts = line.split("\t")
    kind = parts[0]
    if kind == "meta" and len(parts) >= 13:
        doc["platform"] = parts[1]
        doc["platform_label"] = parts[2]
        doc["pkgmgr"] = parts[3]
        doc["dotfiles_dir"] = parts[4]
        doc["dry_run"] = bool(parts[5])
        doc["active_profile"] = parts[6]
        doc["profile_name"] = parts[7]
        doc["profile_description"] = parts[8]
        doc["theme_starship"] = parts[9] or "stock"
        doc["migrate_needed"] = parts[10] == "1"
        doc["missing_git"] = parts[11] == "1"
        doc["missing_curl"] = parts[12] == "1"
    elif kind == "profile" and len(parts) >= 6:
        pid = parts[1]
        profiles_by_id[pid] = {
            "id": pid,
            "name": parts[2],
            "description": parts[3],
            "default": parts[4] == "1",
            "theme_starship": parts[5],
            "packages": [],
        }
    elif kind == "profile_pkg" and len(parts) >= 9:
        pid = parts[1]
        if pid not in profiles_by_id:
            profiles_by_id[pid] = {
                "id": pid, "name": pid, "description": "", "default": False,
                "theme_starship": "stock", "packages": [],
            }
        profiles_by_id[pid]["packages"].append({
            "id": parts[2],
            "name": parts[3],
            "description": parts[4],
            "category": parts[5],
            "default": parts[6] == "1",
            "group": parts[7],
            "generate_only": parts[8] == "true",
        })
    elif kind == "pkg" and len(parts) >= 8:
        doc["packages"].append({
            "id": parts[1],
            "name": parts[2],
            "description": parts[3],
            "category": parts[4],
            "default": parts[5] == "1",
            "group": parts[6],
            "generate_only": parts[7] == "true",
        })
    elif kind == "pkgmgr_opt" and len(parts) >= 4:
        doc["pkgmgr_options"].append({
            "id": parts[1],
            "label": parts[2],
            "default": parts[3] == "1",
        })

doc["profiles"] = [profiles_by_id[k] for k in sorted(profiles_by_id)]
print(json.dumps(doc, indent=2, sort_keys=True))
'
}
