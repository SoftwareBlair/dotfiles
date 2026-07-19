#!/bin/bash
# JSON export of wizard catalog for the Go TUI (and tests)

# Print wizard catalog as JSON on stdout.
# Respects PKG_MGR / PKG_MGR_FLAG and PLATFORM from the caller.
export_wizard_catalog() {
    PKG_MGR="${PKG_MGR_FLAG:-${PKG_MGR:-$(default_pkgmgr)}}"

    local platform_label_str
    platform_label_str="$(platform_label 2>/dev/null || echo "${PLATFORM:-unknown}")"

    if ! command -v python3 >/dev/null 2>&1; then
        echo '{"error":"python3 required for export_wizard_catalog"}' >&2
        return 1
    fi

    {
        echo "meta	${PLATFORM:-}	${platform_label_str}	${PKG_MGR}	${DOTFILES_DIR:-}	${DRY_RUN:-}"
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
    "packages": [],
    "pkgmgr_options": [],
}

for line in sys.stdin:
    line = line.rstrip("\n")
    if not line:
        continue
    parts = line.split("\t")
    kind = parts[0]
    if kind == "meta" and len(parts) >= 6:
        doc["platform"] = parts[1]
        doc["platform_label"] = parts[2]
        doc["pkgmgr"] = parts[3]
        doc["dotfiles_dir"] = parts[4]
        doc["dry_run"] = bool(parts[5])
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

print(json.dumps(doc, indent=2, sort_keys=True))
'
}
