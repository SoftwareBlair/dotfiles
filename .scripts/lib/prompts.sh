#!/bin/bash
# gum wrappers with colored read fallback

ensure_gum() {
    if command -v gum &>/dev/null; then
        return 0
    fi

    local scripts_bin
    scripts_bin="$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd)"
    if [[ -x "$scripts_bin/gum" ]]; then
        export PATH="$scripts_bin:$PATH"
        return 0
    fi

    # Try brew if available
    if command -v brew &>/dev/null; then
        echo "Installing gum (terminal UI) via Homebrew..."
        brew install gum &>/dev/null && command -v gum &>/dev/null && return 0
    fi

    # Download static binary from Charm releases
    local os arch asset tmpdir
    case "$(uname -s)" in
        Darwin) os="Darwin" ;;
        Linux) os="Linux" ;;
        *) GUM_FALLBACK=1; return 1 ;;
    esac
    case "$(uname -m)" in
        x86_64|amd64) arch="x86_64" ;;
        aarch64|arm64) arch="arm64" ;;
        *) GUM_FALLBACK=1; return 1 ;;
    esac

    asset="gum_${os}_${arch}.tar.gz"
    tmpdir="$(mktemp -d)"
    if curl -fsSL --connect-timeout 5 --max-time 30 \
        "https://github.com/charmbracelet/gum/releases/latest/download/${asset}" \
        -o "$tmpdir/gum.tgz" 2>/dev/null; then
        tar -xzf "$tmpdir/gum.tgz" -C "$tmpdir" 2>/dev/null
        local gum_bin
        gum_bin="$(find "$tmpdir" -type f -name gum | head -1)"
        if [[ -n "$gum_bin" ]]; then
            mkdir -p "$scripts_bin"
            cp "$gum_bin" "$scripts_bin/gum"
            chmod +x "$scripts_bin/gum"
            export PATH="$scripts_bin:$PATH"
            rm -rf "$tmpdir"
            return 0
        fi
    fi
    rm -rf "$tmpdir"
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
# Prints selected option to stdout
prompt_choose_one() {
    local header="$1"
    shift
    local options=("$@")

    if [[ -n "${YES_MODE:-}" ]]; then
        echo "${options[0]}"
        return 0
    fi

    if _use_gum; then
        printf '%s\n' "${options[@]}" | gum choose --header "$header"
        return 0
    fi

    echo -e "${Purple}${header}${Off}"
    local i=1
    for opt in "${options[@]}"; do
        echo "  $i) $opt"
        i=$((i + 1))
    done
    local choice
    read -r -p "Enter number [1]: " choice
    choice="${choice:-1}"
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 && "$choice" -le "${#options[@]}" ]]; then
        echo "${options[$((choice - 1))]}"
    else
        echo "${options[0]}"
    fi
}

# prompt_choose_many "Header" option1 option2 ...
# Prints selected options one per line
prompt_choose_many() {
    local header="$1"
    shift
    local options=("$@")

    if [[ ${#options[@]} -eq 0 ]]; then
        return 0
    fi

    if [[ -n "${YES_MODE:-}" ]]; then
        printf '%s\n' "${options[@]}"
        return 0
    fi

    if _use_gum; then
        printf '%s\n' "${options[@]}" | gum choose --no-limit --header "$header"
        return 0
    fi

    echo -e "${Purple}${header}${Off}"
    echo "(Enter comma-separated numbers, or 'all' / 'none')"
    local i=1
    for opt in "${options[@]}"; do
        echo "  $i) $opt"
        i=$((i + 1))
    done
    local choice
    read -r -p "Selection [all]: " choice
    choice="${choice:-all}"
    if [[ "$choice" == "all" ]]; then
        printf '%s\n' "${options[@]}"
        return 0
    fi
    if [[ "$choice" == "none" ]]; then
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
