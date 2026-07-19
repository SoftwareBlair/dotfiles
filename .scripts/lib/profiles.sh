#!/bin/bash
# Community setup profiles (profiles/<GitHubUsername>.toml)

DEFAULT_PROFILE="${DEFAULT_PROFILE:-SoftwareBlair}"
PROFILE_FLAG="${PROFILE_FLAG:-}"
PROFILE_ID=""
PROFILE_NAME=""
PROFILE_DESCRIPTION=""
PROFILE_CONFIG_ROOT=""
PROFILE_LINK_TARGETS=()
# Flat "pkg:path" entries from [link_if] (Bash 3–compatible; no assoc arrays)
PROFILE_LINK_IF_ENTRIES=()

profiles_dir() {
    echo "${DOTFILES_DIR:-}/profiles"
}

# List profile IDs (sorted), one per line.
profiles_list() {
    local dir
    dir="$(profiles_dir)"
    [[ -d "$dir" ]] || return 0
    local f base
    for f in "$dir"/*.toml; do
        [[ -f "$f" ]] || continue
        base="$(basename "$f" .toml)"
        [[ -n "$base" ]] && echo "$base"
    done | LC_ALL=C sort -u
}

# Emit profile metadata as TSV: id\tname\tdescription
profiles_meta_tsv() {
    local dir
    dir="$(profiles_dir)"
    command -v python3 >/dev/null 2>&1 || return 1
    PROFILE_DIR="$dir" python3 - <<'PY'
import os, sys
from pathlib import Path

try:
    import tomllib
except ImportError:
    import tomli as tomllib  # type: ignore

root = Path(os.environ["PROFILE_DIR"])
if not root.is_dir():
    sys.exit(0)

for path in sorted(root.glob("*.toml")):
    try:
        data = tomllib.loads(path.read_text(encoding="utf-8"))
    except Exception as e:
        print(f"warning: skip {path.name}: {e}", file=sys.stderr)
        continue
    github = str(data.get("github") or path.stem)
    if github != path.stem:
        print(
            f"warning: {path.name}: github={github!r} does not match filename; using filename",
            file=sys.stderr,
        )
        github = path.stem
    name = str(data.get("name") or github)
    desc = str(data.get("description") or "")
    print(f"{github}\t{name}\t{desc}")
PY
}

# Parse profile JSON blob into globals (single python decode).
_profile_apply_json() {
    local dumped="$1"
    eval "$(PROFILE_JSON="$dumped" python3 - <<'PY'
import json, shlex, os
d = json.loads(os.environ["PROFILE_JSON"])

def sh_array(name, items):
    print(f"{name}=(")
    for x in items:
        print(f"  {shlex.quote(str(x))}")
    print(")")

print(f"PROFILE_ID={shlex.quote(d['id'])}")
print(f"PROFILE_NAME={shlex.quote(d['name'])}")
print(f"PROFILE_DESCRIPTION={shlex.quote(d['description'])}")
print(f"MY_SETUP={shlex.quote(' '.join(d['packages']))}")
print(f"MY_SETUP_MACOS={shlex.quote(' '.join(d['packages_macos']))}")
print(f"MY_SETUP_OPTIONAL={shlex.quote(' '.join(d['packages_optional']))}")
print(f"HELP_INCLUDES_EDITORS={shlex.quote(d['help_editors'])}")
print(f"HELP_INCLUDES_TERMINAL={shlex.quote(d['help_terminal'])}")
print(f"HELP_INCLUDES_SHELL={shlex.quote(d['help_shell'])}")
print(f"_PROFILE_CONFIG_REL={shlex.quote(d['config_root'])}")
sh_array("PROFILE_LINK_TARGETS", d["link"])
entries = []
for pkg, paths in (d.get("link_if") or {}).items():
    for p in paths:
        entries.append(f"{pkg}:{p}")
sh_array("PROFILE_LINK_IF_ENTRIES", entries)
PY
)"
}

# Load a profile into MY_SETUP* / PROFILE_* globals.
# Usage: profile_load <GitHubUsername>
profile_load() {
    local id="$1"
    [[ -n "$id" ]] || return 1
    local path
    path="$(profiles_dir)/${id}.toml"
    [[ -f "$path" ]] || {
        echo "Profile not found: $id ($path)" >&2
        return 1
    }
    command -v python3 >/dev/null 2>&1 || {
        echo "python3 is required to load profiles" >&2
        return 1
    }

    local dumped
    dumped="$(PROFILE_TOML="$path" PROFILE_EXPECT_ID="$id" python3 - <<'PY'
import os, json, sys
from pathlib import Path

try:
    import tomllib
except ImportError:
    import tomli as tomllib  # type: ignore

path = Path(os.environ["PROFILE_TOML"])
expect = os.environ["PROFILE_EXPECT_ID"]
data = tomllib.loads(path.read_text(encoding="utf-8"))
github = str(data.get("github") or path.stem)
if github != expect:
    print(f"error: {path.name}: github={github!r} must match filename {expect!r}", file=sys.stderr)
    sys.exit(1)

def str_list(key):
    val = data.get(key) or []
    if not isinstance(val, list):
        raise SystemExit(f"error: {key} must be an array")
    return [str(x) for x in val]

link_if = data.get("link_if") or {}
if not isinstance(link_if, dict):
    raise SystemExit("error: link_if must be a table")
link_if_norm = {}
for k, v in link_if.items():
    if not isinstance(v, list):
        # Ignore scalars accidentally placed under [link_if] (TOML table scoping)
        continue
    link_if_norm[str(k)] = [str(x) for x in v]

doc = {
    "id": expect,
    "name": str(data.get("name") or expect),
    "description": str(data.get("description") or ""),
    "packages": str_list("packages"),
    "packages_macos": str_list("packages_macos"),
    "packages_optional": str_list("packages_optional"),
    "link": str_list("link"),
    "link_if": link_if_norm,
    "config_root": str(data.get("config_root") or "."),
    "help_editors": str(data.get("help_editors") or ""),
    "help_terminal": str(data.get("help_terminal") or ""),
    "help_shell": str(data.get("help_shell") or ""),
}
print(json.dumps(doc))
PY
)" || return 1

    local _PROFILE_CONFIG_REL=""
    _profile_apply_json "$dumped" || return 1

    if [[ "$_PROFILE_CONFIG_REL" == "." || -z "$_PROFILE_CONFIG_REL" ]]; then
        PROFILE_CONFIG_ROOT="$DOTFILES_DIR"
    else
        PROFILE_CONFIG_ROOT="$DOTFILES_DIR/$_PROFILE_CONFIG_REL"
    fi

    PRESET_NAME="$PROFILE_ID"
    return 0
}

# Resolve which profile to use (flag → env → saved → default).
profile_resolve_id() {
    if [[ -n "${PROFILE_FLAG:-}" ]]; then
        echo "$PROFILE_FLAG"
        return
    fi
    if [[ -n "${SETUP_PROFILE:-}" ]]; then
        echo "$SETUP_PROFILE"
        return
    fi
    if [[ -n "${DOTFILES_PROFILE:-}" ]]; then
        echo "$DOTFILES_PROFILE"
        return
    fi
    if [[ -n "${LAST_PROFILE:-}" ]]; then
        local path
        path="$(profiles_dir)/${LAST_PROFILE}.toml"
        if [[ -f "$path" ]]; then
            echo "$LAST_PROFILE"
            return
        fi
    fi
    echo "$DEFAULT_PROFILE"
}

# Interactive (or auto) profile selection, then profile_load.
pick_profile() {
    local chosen=""
    local ids=""
    local id
    ids="$(profiles_list)"
    if [[ -z "$ids" ]]; then
        echo "No profiles found in $(profiles_dir)" >&2
        return 1
    fi

    local count
    count="$(printf '%s\n' "$ids" | sed '/^$/d' | wc -l | tr -d ' ')"

    if [[ -n "${PROFILE_FLAG:-}" || -n "${SETUP_PROFILE:-}" || -n "${DOTFILES_PROFILE:-}" ]]; then
        chosen="$(profile_resolve_id)"
    elif [[ -n "${YES_MODE:-}" ]]; then
        chosen="$(profile_resolve_id)"
    elif [[ "$count" -eq 1 ]]; then
        chosen="$(printf '%s\n' "$ids" | head -n 1)"
    else
        local labels=()
        local name desc default_id
        default_id="$(profile_resolve_id)"
        while IFS=$'\t' read -r id name desc; do
            [[ -z "$id" ]] && continue
            if [[ "$id" == "$default_id" ]]; then
                labels+=("${name} (@${id})  [default]")
            elif [[ -n "$desc" ]]; then
                labels+=("${name} (@${id}) — ${desc}")
            else
                labels+=("${name} (@${id})")
            fi
        done < <(profiles_meta_tsv)

        echo ""
        prompt_style "Choose a setup profile"
        prompt_info "Community setups — named after GitHub usernames. Add yours under profiles/."
        local pick
        pick="$(prompt_choose_one "Setup profile" "${labels[@]}")"
        chosen="$(printf '%s' "$pick" | sed -n 's/.*(@\([^)]*\)).*/\1/p')"
        [[ -n "$chosen" ]] || chosen="$default_id"
    fi

    profile_load "$chosen" || return 1
    if command -v prompt_info >/dev/null 2>&1; then
        prompt_info "Profile: ${PROFILE_NAME} (@${PROFILE_ID})"
    fi
    return 0
}

# Apply symlink targets from the loaded profile (+ link_if for selected packages).
profile_apply_symlinks() {
    SYMLINK_TARGETS=("${PROFILE_LINK_TARGETS[@]}")
    local entry pkg path
    for entry in "${PROFILE_LINK_IF_ENTRIES[@]:-}"; do
        [[ -z "$entry" ]] && continue
        pkg="${entry%%:*}"
        path="${entry#*:}"
        if [[ " ${SELECTED_IDS[*]} " == *" $pkg "* ]]; then
            case " ${SYMLINK_TARGETS[*]} " in
                *" $path "*) ;;
                *) SYMLINK_TARGETS+=("$path") ;;
            esac
        fi
    done
    LINK_MODE="symlink"
    SHELL_PROFILE_MODE="starship"
}
