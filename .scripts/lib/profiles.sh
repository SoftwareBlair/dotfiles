#!/bin/bash
# Community setup profiles (profiles/<GitHubUsername>.toml)

DEFAULT_PROFILE="${DEFAULT_PROFILE:-default}"
PROFILE_FLAG="${PROFILE_FLAG:-}"
PROFILE_ID=""
PROFILE_NAME=""
PROFILE_DESCRIPTION=""
THEME_STARSHIP="stock"
PROFILE_PACKAGES_SHELL=""
PROFILE_PACKAGES_DEV=""
MY_SETUP=""
MY_SETUP_MACOS=""
MY_SETUP_OPTIONAL=""
HELP_INCLUDES_EDITORS=""
HELP_INCLUDES_TERMINAL=""
HELP_INCLUDES_SHELL=""

profiles_dir() {
    echo "${DOTFILES_DIR:-}/profiles"
}

profiles_list() {
    local dir f base
    dir="$(profiles_dir)"
    [[ -d "$dir" ]] || return 0
    for f in "$dir"/*.toml; do
        [[ -f "$f" ]] || continue
        base="$(basename "$f" .toml)"
        [[ -n "$base" ]] && echo "$base"
    done | LC_ALL=C sort -u
}

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
        github = path.stem
    name = str(data.get("name") or github)
    desc = str(data.get("description") or "")
    print(f"{github}\t{name}\t{desc}")
PY
}

_profile_apply_json() {
    local dumped="$1"
    eval "$(PROFILE_JSON="$dumped" python3 - <<'PY'
import json, shlex, os
d = json.loads(os.environ["PROFILE_JSON"])

def q(s):
    return shlex.quote(str(s))

shell = d.get("packages_shell") or d.get("packages") or []
dev = d.get("packages_dev") or []
macos = d.get("packages_macos") or []
optional = d.get("packages_optional") or []
themes = d.get("themes") or {}

print(f"PROFILE_ID={q(d['id'])}")
print(f"PROFILE_NAME={q(d['name'])}")
print(f"PROFILE_DESCRIPTION={q(d['description'])}")
print(f"PROFILE_PACKAGES_SHELL={q(' '.join(shell))}")
print(f"PROFILE_PACKAGES_DEV={q(' '.join(dev))}")
print(f"MY_SETUP={q(' '.join(list(shell) + list(dev)))}")
print(f"MY_SETUP_MACOS={q(' '.join(macos))}")
print(f"MY_SETUP_OPTIONAL={q(' '.join(optional))}")
print(f"THEME_STARSHIP={q(themes.get('starship') or 'stock')}")
print(f"HELP_INCLUDES_EDITORS={q(d.get('help_editors') or '')}")
print(f"HELP_INCLUDES_TERMINAL={q(d.get('help_terminal') or d.get('description') or '')}")
print(f"HELP_INCLUDES_SHELL={q(d.get('help_shell') or '')}")
PY
)"
}

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

def str_list(key, fallback=None):
    val = data.get(key)
    if val is None and fallback is not None:
        val = data.get(fallback) or []
    val = val or []
    if not isinstance(val, list):
        raise SystemExit(f"error: {key} must be an array")
    return [str(x) for x in val]

themes = data.get("themes") or {}
if not isinstance(themes, dict):
    raise SystemExit("error: themes must be a table")

# Prefer packages_shell; fall back to legacy packages
shell = str_list("packages_shell", "packages")
dev = str_list("packages_dev")

doc = {
    "id": expect,
    "name": str(data.get("name") or expect),
    "description": str(data.get("description") or ""),
    "packages_shell": shell,
    "packages_dev": dev,
    "packages_macos": str_list("packages_macos"),
    "packages_optional": str_list("packages_optional"),
    "themes": {str(k): str(v) for k, v in themes.items()},
    "help_editors": str(data.get("help_editors") or ""),
    "help_terminal": str(data.get("help_terminal") or ""),
    "help_shell": str(data.get("help_shell") or ""),
}
print(json.dumps(doc))
PY
)" || return 1

    _profile_apply_json "$dumped" || return 1
    PRESET_NAME="$PROFILE_ID"
    return 0
}

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

pick_profile() {
    local chosen="" ids count id
    ids="$(profiles_list)"
    if [[ -z "$ids" ]]; then
        echo "No profiles found in $(profiles_dir)" >&2
        return 1
    fi
    count="$(printf '%s\n' "$ids" | sed '/^$/d' | wc -l | tr -d ' ')"

    if [[ -n "${PROFILE_FLAG:-}" || -n "${SETUP_PROFILE:-}" || -n "${DOTFILES_PROFILE:-}" ]]; then
        chosen="$(profile_resolve_id)"
    elif [[ -n "${YES_MODE:-}" ]]; then
        chosen="$(profile_resolve_id)"
    elif [[ "$count" -eq 1 ]]; then
        chosen="$(printf '%s\n' "$ids" | head -n 1)"
    else
        local labels=() name desc default_id
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
        prompt_info "Default = fresh install. Community profiles contribute package + theme choices."
        local pick
        pick="$(prompt_choose_one "Setup profile" "${labels[@]}")"
        chosen="$(printf '%s' "$pick" | sed -n 's/.*(@\([^)]*\)).*/\1/p')"
        [[ -n "$chosen" ]] || chosen="$default_id"
    fi

    profile_load "$chosen" || return 1
    if command -v prompt_info >/dev/null 2>&1; then
        prompt_info "Profile: ${PROFILE_NAME} (@${PROFILE_ID}) · theme starship=${THEME_STARSHIP}"
    fi
    return 0
}

# Shell-category ids from loaded profile (for pickers)
profile_shell_ids() {
    local ids="$PROFILE_PACKAGES_SHELL"
    if [[ "${PLATFORM:-}" == "macos" ]]; then
        # macos extras that are shell-related stay in MY_SETUP_MACOS merge via my_setup_ids
        :
    fi
    echo "$ids"
}

profile_dev_ids() {
    echo "$PROFILE_PACKAGES_DEV"
}
