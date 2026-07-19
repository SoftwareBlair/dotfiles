#!/bin/bash
# JSON export of wizard catalog for the Go TUI (and tests)

# Print wizard catalog as JSON on stdout.
# Respects PKG_MGR / PKG_MGR_FLAG, PLATFORM, and profile selection from the caller.
export_wizard_catalog() {
    PKG_MGR="${PKG_MGR_FLAG:-${PKG_MGR:-$(default_pkgmgr)}}"
    load_setup_prefs 2>/dev/null || true

    local active_id
    active_id="$(profile_resolve_id)"
    if ! profile_load "$active_id" 2>/dev/null; then
        # Fall back to first available / default file
        active_id="$(profiles_list | head -n 1)"
        [[ -n "$active_id" ]] || {
            echo '{"error":"no profiles found under profiles/"}' >&2
            return 1
        }
        profile_load "$active_id" || return 1
    fi

    local platform_label_str
    platform_label_str="$(platform_label 2>/dev/null || echo "${PLATFORM:-unknown}")"

    if ! command -v python3 >/dev/null 2>&1; then
        echo '{"error":"python3 required for export_wizard_catalog"}' >&2
        return 1
    fi

    {
        echo "meta	${PLATFORM:-}	${platform_label_str}	${PKG_MGR}	${DOTFILES_DIR:-}	${DRY_RUN:-}	${PROFILE_ID}	${PROFILE_NAME}	${PROFILE_DESCRIPTION}"

        local pid pname pdesc
        while IFS=$'\t' read -r pid pname pdesc; do
            [[ -z "$pid" ]] && continue
            local is_default=0
            [[ "$pid" == "$active_id" ]] && is_default=1
            printf 'profile\t%s\t%s\t%s\t%s\n' "$pid" "$pname" "$pdesc" "$is_default"

            # Resolve packages for this profile on the current platform
            if profile_load "$pid" 2>/dev/null; then
                local id name desc category
                for id in $(my_setup_ids); do
                    catalog_available "$id" || continue
                    name="$(catalog_get "$id" name)"
                    desc="$(catalog_get "$id" description)"
                    category="$(catalog_get "$id" category)"
                    printf 'profile_pkg\t%s\t%s\t%s\t%s\t%s\t1\n' "$pid" "$id" "$name" "$desc" "$category"
                done
            fi
        done < <(profiles_meta_tsv)

        # Active profile packages (top-level, for backward-compatible TUI fixtures)
        profile_load "$active_id" || return 1
        local id name desc category
        for id in $(my_setup_ids); do
            catalog_available "$id" || continue
            name="$(catalog_get "$id" name)"
            desc="$(catalog_get "$id" description)"
            category="$(catalog_get "$id" category)"
            printf 'pkg\t%s\t%s\t%s\t%s\t1\n' "$id" "$name" "$desc" "$category"
        done

        echo "pkgmgr_opt	brew	Homebrew (brew)	1"
        if [[ "${PLATFORM:-}" == "linux" ]]; then
            command -v apt-get &>/dev/null && echo "pkgmgr_opt	apt	apt — Debian/Ubuntu	0"
            command -v dnf &>/dev/null && echo "pkgmgr_opt	dnf	dnf — Fedora/RHEL	0"
            command -v pacman &>/dev/null && echo "pkgmgr_opt	pacman	pacman — Arch	0"
        fi
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
    if kind == "meta" and len(parts) >= 9:
        doc["platform"] = parts[1]
        doc["platform_label"] = parts[2]
        doc["pkgmgr"] = parts[3]
        doc["dotfiles_dir"] = parts[4]
        doc["dry_run"] = bool(parts[5])
        doc["active_profile"] = parts[6]
        doc["profile_name"] = parts[7]
        doc["profile_description"] = parts[8]
    elif kind == "profile" and len(parts) >= 5:
        pid = parts[1]
        profiles_by_id[pid] = {
            "id": pid,
            "name": parts[2],
            "description": parts[3],
            "default": parts[4] == "1",
            "packages": [],
        }
    elif kind == "profile_pkg" and len(parts) >= 7:
        pid = parts[1]
        if pid not in profiles_by_id:
            profiles_by_id[pid] = {
                "id": pid,
                "name": pid,
                "description": "",
                "default": False,
                "packages": [],
            }
        profiles_by_id[pid]["packages"].append({
            "id": parts[2],
            "name": parts[3],
            "description": parts[4],
            "category": parts[5],
            "default": parts[6] == "1",
        })
    elif kind == "pkg" and len(parts) >= 6:
        doc["packages"].append({
            "id": parts[1],
            "name": parts[2],
            "description": parts[3],
            "category": parts[4],
            "default": parts[5] == "1",
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
