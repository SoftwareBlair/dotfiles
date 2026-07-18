#!/bin/bash
# gum wrappers with colored read fallback

ensure_gum() {
    # Use gum only if already available — never auto-install (keeps setup fast/predictable)
    if command -v gum &>/dev/null; then
        return 0
    fi

    local scripts_bin
    scripts_bin="$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd)"
    if [[ -x "$scripts_bin/gum" ]]; then
        export PATH="$scripts_bin:$PATH"
        return 0
    fi

    GUM_FALLBACK=1
    return 1
}

_use_gum() {
    command -v gum &>/dev/null && [[ -z "${GUM_FALLBACK:-}" ]] && [[ -z "${YES_MODE:-}" ]]
}

prompt_welcome() {
    local line1="${1:-Developer Machine Setup}"
    local line2="${2:-}"
    if _use_gum; then
        gum style --border double --padding "1 2" --align center --border-foreground 45 \
            "$line1" "$line2"
    else
        echo ""
        echo "========================================"
        echo "  $line1"
        [[ -n "$line2" ]] && echo "  $line2"
        echo "========================================"
        echo ""
    fi
}

prompt_style() {
    local text="$1"
    if _use_gum; then
        gum style --foreground 212 --bold "$text"
    else
        echo -e "${BackCyan}${text}${Off}"
    fi
}

prompt_confirm() {
    local message="$1"
    local default="${2:-false}"

    if [[ -n "${YES_MODE:-}" ]]; then
        return 0
    fi

    if _use_gum; then
        if [[ "$default" == "true" ]]; then
            gum confirm "$message" && return 0 || return 1
        else
            gum confirm --default=false "$message" && return 0 || return 1
        fi
    fi

    local answer
    if [[ "$default" == "true" ]]; then
        echo -e "${Purple}${message} (Y/n): ${Off}"
        read -r answer
        [[ -z "$answer" || "$answer" = [Yy]* ]]
    else
        echo -e "${Purple}${message} (y/n): ${Off}"
        read -r answer
        [[ "$answer" = [Yy]* ]]
    fi
}

prompt_input() {
    local placeholder="$1"
    local default="${2:-}"
    local value

    # Non-interactive: never block on stdin
    if [[ -n "${YES_MODE:-}" ]]; then
        echo "$default"
        return 0
    fi

    if _use_gum; then
        if [[ -n "$default" ]]; then
            gum input --placeholder "$placeholder" --value "$default"
        else
            gum input --placeholder "$placeholder"
        fi
        return 0
    fi

    if [[ -n "$default" ]]; then
        read -r -p "$placeholder [$default]: " value
        echo "${value:-$default}"
    else
        read -r -p "$placeholder: " value
        echo "$value"
    fi
}

# prompt_choose_one "Header" option1 option2 ...
# Prints selected option to stdout.
# Prefer an option marked [default] when present.
prompt_choose_one() {
    local header="$1"
    shift
    local options=("$@")

    local default_idx=0
    local i
    for i in "${!options[@]}"; do
        if [[ "${options[$i]}" == *"[default]"* ]]; then
            default_idx=$i
            break
        fi
    done

    if [[ -n "${YES_MODE:-}" ]]; then
        echo "${options[$default_idx]}"
        return 0
    fi

    if _use_gum; then
        # gum highlights the first item; put default first for visibility
        local ordered=()
        ordered+=("${options[$default_idx]}")
        for i in "${!options[@]}"; do
            [[ "$i" -eq "$default_idx" ]] && continue
            ordered+=("${options[$i]}")
        done
        printf '%s\n' "${ordered[@]}" | gum choose --header "$header"
        return 0
    fi

    echo -e "${Purple}${header}${Off}"
    local n=1
    for opt in "${options[@]}"; do
        echo "  $n) $opt"
        n=$((n + 1))
    done
    local choice
    read -r -p "Enter number [$((default_idx + 1))]: " choice
    choice="${choice:-$((default_idx + 1))}"
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 && "$choice" -le "${#options[@]}" ]]; then
        echo "${options[$((choice - 1))]}"
    else
        echo "${options[$default_idx]}"
    fi
}

# prompt_choose_many "Header" option1 option2 ...
# Prints selected options one per line.
# Options marked with "[default]" are pre-selected in gum / suggested in fallback.
prompt_choose_many() {
    local header="$1"
    shift
    local options=("$@")

    if [[ ${#options[@]} -eq 0 ]]; then
        return 0
    fi

    if [[ -n "${YES_MODE:-}" ]]; then
        # Prefer defaults when present; otherwise all
        local defaults=()
        local opt
        for opt in "${options[@]}"; do
            [[ "$opt" == *"[default]"* ]] && defaults+=("$opt")
        done
        if [[ ${#defaults[@]} -gt 0 ]]; then
            printf '%s\n' "${defaults[@]}"
        else
            printf '%s\n' "${options[@]}"
        fi
        return 0
    fi

    if _use_gum; then
        local gum_args=(choose --no-limit --header "$header")
        for opt in "${options[@]}"; do
            if [[ "$opt" == *"[default]"* ]]; then
                gum_args+=(--selected "$opt")
            fi
        done
        printf '%s\n' "${options[@]}" | gum "${gum_args[@]}"
        return 0
    fi

    echo -e "${Purple}${header}${Off}"
    echo "(Enter comma-separated numbers, 'defaults', 'all', or 'none')"
    local i=1
    local default_nums=()
    for opt in "${options[@]}"; do
        if [[ "$opt" == *"[default]"* ]]; then
            echo "  $i) $opt"
            default_nums+=("$i")
        else
            echo "  $i) $opt"
        fi
        i=$((i + 1))
    done
    local default_hint="all"
    if [[ ${#default_nums[@]} -gt 0 ]]; then
        local IFS=','
        default_hint="defaults (${default_nums[*]})"
        unset IFS
    fi
    local choice
    read -r -p "Selection [$default_hint]: " choice
    if [[ -z "$choice" ]]; then
        if [[ ${#default_nums[@]} -gt 0 ]]; then
            choice="defaults"
        else
            choice="all"
        fi
    fi
    if [[ "$choice" == "all" ]]; then
        printf '%s\n' "${options[@]}"
        return 0
    fi
    if [[ "$choice" == "none" ]]; then
        return 0
    fi
    if [[ "$choice" == "defaults" ]]; then
        for opt in "${options[@]}"; do
            [[ "$opt" == *"[default]"* ]] && echo "$opt"
        done
        return 0
    fi
    local IFS=','
    local nums
    read -r -a nums <<< "$choice"
    for n in "${nums[@]}"; do
        n="$(echo "$n" | tr -d ' ')"
        if [[ "$n" =~ ^[0-9]+$ ]] && [[ "$n" -ge 1 && "$n" -le "${#options[@]}" ]]; then
            echo "${options[$((n - 1))]}"
        fi
    done
}

prompt_spin() {
    local title="$1"
    shift
    if _use_gum && ! dry_run_is_active 2>/dev/null; then
        gum spin --spinner dot --title "$title" -- "$@"
    else
        echo -e "${Blue}${title}${Off}"
        "$@"
    fi
}

prompt_info() {
    echo -e "${Cyan}$1${Off}"
}

prompt_warn() {
    echo -e "${Yellow}$1${Off}"
}

prompt_error() {
    echo -e "${Red}$1${Off}"
}

prompt_success() {
    echo -e "${Green}$1${Off}"
}
