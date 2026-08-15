#!/bin/bash
# Dry-run plan builder and formatted preview

DRY_RUN_STEPS=()

dry_run_is_active() {
    [[ -n "${DRY_RUN:-}" && "$DRY_RUN" != "0" ]]
}

dry_run_begin_plan() {
    DRY_RUN_STEPS=()
}

# Record separator unlikely to appear in shell commands
_DRY_SEP=$'\x1f'

# dry_run_add_step name command dest side_effects requires_sudo skip_reason
dry_run_add_step() {
    local name="$1"
    local command="$2"
    local dest="${3:-}"
    local side_effects="${4:-}"
    local requires_sudo="${5:-false}"
    local skip_reason="${6:-}"
    DRY_RUN_STEPS+=("${name}${_DRY_SEP}${command}${_DRY_SEP}${dest}${_DRY_SEP}${side_effects}${_DRY_SEP}${requires_sudo}${_DRY_SEP}${skip_reason}")
}

_dry_run_field() {
    local record="$1"
    local index="$2"
    printf '%s' "$record" | awk -F '\037' -v i="$index" '{ print $i }'
}

dry_run_print_plan() {
    local title="${1:-Install Plan}"
    local count="${#DRY_RUN_STEPS[@]}"
    local sudo_count=0
    local skip_count=0
    local i

    for i in "${DRY_RUN_STEPS[@]}"; do
        local requires_sudo skip_reason
        requires_sudo="$(_dry_run_field "$i" 5)"
        skip_reason="$(_dry_run_field "$i" 6)"
        [[ "$requires_sudo" == "true" ]] && sudo_count=$((sudo_count + 1))
        [[ -n "$skip_reason" ]] && skip_count=$((skip_count + 1))
    done

    if command -v gum &>/dev/null && [[ -z "${GUM_FALLBACK:-}" ]]; then
        gum style --border double --padding "0 2" --border-foreground 212 \
            "$title (dry run)" \
            "OS: $(platform_label) · ${PKG_MGR:-unknown}" \
            "$count items · $sudo_count require sudo · $skip_count already installed / skipped"
    else
        echo ""
        echo "=== $title (dry run) ==="
        echo "OS: $(platform_label) · ${PKG_MGR:-unknown}"
        echo "$count items · $sudo_count require sudo · $skip_count already installed / skipped"
        echo ""
    fi

    local idx=1
    for i in "${DRY_RUN_STEPS[@]}"; do
        local name command dest side_effects requires_sudo skip_reason
        name="$(_dry_run_field "$i" 1)"
        command="$(_dry_run_field "$i" 2)"
        dest="$(_dry_run_field "$i" 3)"
        side_effects="$(_dry_run_field "$i" 4)"
        requires_sudo="$(_dry_run_field "$i" 5)"
        skip_reason="$(_dry_run_field "$i" 6)"

        echo ""
        echo " $idx. $name"
        if [[ -n "$skip_reason" ]]; then
            echo "    (skip) $skip_reason"
        else
            echo "    → $command"
            [[ -n "$dest" ]] && echo "    → installs to: $dest"
            [[ -n "$side_effects" ]] && echo "    → side effects: $side_effects"
            [[ "$requires_sudo" == "true" ]] && echo "    → requires: sudo"
        fi
        idx=$((idx + 1))
    done

    echo ""
    echo "No changes were made. Run without --dry-run to apply."
}

# If dry-run: record step and return 0. Else: run the command.
# Usage: dry_run_exec "Name" "command string" [dest] [side_effects] [requires_sudo]
dry_run_exec() {
    local name="$1"
    local cmd="$2"
    local dest="${3:-}"
    local side_effects="${4:-}"
    local requires_sudo="${5:-false}"

    if dry_run_is_active; then
        dry_run_add_step "$name" "$cmd" "$dest" "$side_effects" "$requires_sudo" ""
        return 0
    fi

    eval "$cmd"
}
