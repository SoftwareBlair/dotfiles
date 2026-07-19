#!/bin/bash
# gum wrappers with colored read fallback

_gum_already_available() {
    if command -v gum &>/dev/null; then
        return 0
    fi
    local scripts_bin
    scripts_bin="$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd)"
    if [[ -x "$scripts_bin/gum" ]]; then
        export PATH="$scripts_bin:$PATH"
        return 0
    fi
    return 1
}

# Download Charm gum into .scripts/bin (fallback when brew install gum fails).
_install_gum_from_github() {
    local scripts_bin os arch version asset url tmpdir gum_bin
    scripts_bin="$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd)"

    case "$(uname -s)" in
        Darwin) os="Darwin" ;;
        Linux) os="Linux" ;;
        *)
            echo -e "${Yellow:-}Unsupported OS for gum download: $(uname -s)${Off:-}" >&2
            return 1
            ;;
    esac
    case "$(uname -m)" in
        x86_64|amd64) arch="x86_64" ;;
        aarch64|arm64) arch="arm64" ;;
        *)
            echo -e "${Yellow:-}Unsupported architecture for gum download: $(uname -m)${Off:-}" >&2
            return 1
            ;;
    esac

    version="$(
        curl -fsSL --connect-timeout 5 --max-time 20 \
            "https://api.github.com/repos/charmbracelet/gum/releases/latest" 2>/dev/null \
            | sed -n 's/.*"tag_name":[[:space:]]*"v\([^"]*\)".*/\1/p' \
            | head -n 1
    )"
    [[ -z "$version" ]] && version="0.17.0"

    asset="gum_${version}_${os}_${arch}.tar.gz"
    url="https://github.com/charmbracelet/gum/releases/download/v${version}/${asset}"
    tmpdir="$(mktemp -d)"
    echo -e "${Cyan:-}Downloading gum v${version}…${Off:-}"
    if ! curl -fsSL --connect-timeout 5 --max-time 60 "$url" -o "$tmpdir/gum.tgz"; then
        echo -e "${Yellow:-}Failed to download ${asset}${Off:-}" >&2
        rm -rf "$tmpdir"
        return 1
    fi
    if ! tar -xzf "$tmpdir/gum.tgz" -C "$tmpdir"; then
        echo -e "${Yellow:-}Failed to extract gum archive${Off:-}" >&2
        rm -rf "$tmpdir"
        return 1
    fi
    gum_bin="$(find "$tmpdir" -type f -name gum | head -n 1)"
    if [[ -z "$gum_bin" || ! -f "$gum_bin" ]]; then
        echo -e "${Yellow:-}gum binary not found in archive${Off:-}" >&2
        rm -rf "$tmpdir"
        return 1
    fi
    mkdir -p "$scripts_bin"
    cp "$gum_bin" "$scripts_bin/gum"
    chmod +x "$scripts_bin/gum"
    export PATH="$scripts_bin:$PATH"
    rm -rf "$tmpdir"
    command -v gum &>/dev/null
}

_install_gum_via_brew() {
    if ! brew_is_available 2>/dev/null; then
        return 1
    fi
    echo -e "${Cyan:-}Installing gum via Homebrew…${Off:-}"
    if brew install gum && command -v gum &>/dev/null; then
        return 0
    fi
    return 1
}

# Offer Homebrew + gum when missing so the rest of setup can use nicer prompts.
# Uses plain read (gum isn't available yet). -y skips the offer.
# During dry-run: never install Homebrew (it writes ~/.zprofile); only offer a
# local gum download for better prompts.
# Always returns 0 so setup can continue with basic prompts when declined/failed.
ensure_gum() {
    if _gum_already_available; then
        unset GUM_FALLBACK 2>/dev/null || true
        return 0
    fi

    if [[ -n "${YES_MODE:-}" ]]; then
        GUM_FALLBACK=1
        return 0
    fi

    local brew_ready=0
    if brew_is_available 2>/dev/null; then
        brew_ready=1
    fi

    echo ""
    local answer
    if dry_run_is_active 2>/dev/null; then
        # Dry-run must not install Homebrew (installer + shellenv write ~/.zprofile)
        echo -e "${Purple:-}gum${Off:-} is not installed. It provides a nicer interactive UI."
        echo -e "${Purple:-}Download gum for better dry-run prompts? (Y/n): ${Off:-}"
        read -r answer
        if [[ -n "$answer" && "$answer" != [Yy]* ]]; then
            echo -e "${Yellow:-}Using basic prompts.${Off:-}"
            GUM_FALLBACK=1
            return 0
        fi
        if _install_gum_from_github; then
            unset GUM_FALLBACK 2>/dev/null || true
            echo -e "${Green:-}✓ gum ready${Off:-}"
            return 0
        fi
        echo -e "${Yellow:-}Could not download gum — using basic prompts.${Off:-}"
        GUM_FALLBACK=1
        return 0
    fi

    if [[ "$brew_ready" -eq 1 ]]; then
        echo -e "${Purple:-}gum${Off:-} is not installed. It provides a nicer interactive UI for setup."
        echo -e "${Purple:-}Install gum with Homebrew for a better experience? (Y/n): ${Off:-}"
    else
        echo -e "${Purple:-}Homebrew${Off:-} and ${Purple:-}gum${Off:-} are not installed."
        echo -e "  Homebrew is the preferred package manager for this setup."
        echo -e "  gum provides nicer interactive prompts."
        echo -e "${Purple:-}Install Homebrew and gum for a better setup experience? (Y/n): ${Off:-}"
    fi
    read -r answer
    if [[ -n "$answer" && "$answer" != [Yy]* ]]; then
        echo -e "${Yellow:-}Using basic prompts.${Off:-}"
        GUM_FALLBACK=1
        return 0
    fi

    if [[ "$brew_ready" -eq 0 ]]; then
        if ! install_homebrew; then
            echo -e "${Yellow:-}Could not install Homebrew — using basic prompts.${Off:-}"
            GUM_FALLBACK=1
            return 0
        fi
        PKG_MGR="${PKG_MGR:-brew}"
    fi

    if _install_gum_via_brew || _install_gum_from_github; then
        unset GUM_FALLBACK 2>/dev/null || true
        echo -e "${Green:-}✓ gum ready${Off:-}"
        return 0
    fi

    echo -e "${Yellow:-}Could not install gum — using basic prompts.${Off:-}"
    GUM_FALLBACK=1
    return 0
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

    echo -e "${BackCyan}${header}${Off}"
    for i in "${!options[@]}"; do
        local mark=" "
        [[ "$i" -eq "$default_idx" ]] && mark="*"
        printf "  %s %d) %s\n" "$mark" "$((i + 1))" "${options[$i]}"
    done
    local pick
    read -r -p "Choice [$((default_idx + 1))]: " pick
    if [[ -z "$pick" ]]; then
        echo "${options[$default_idx]}"
        return 0
    fi
    if [[ "$pick" =~ ^[0-9]+$ ]] && [[ "$pick" -ge 1 && "$pick" -le ${#options[@]} ]]; then
        echo "${options[$((pick - 1))]}"
    else
        echo "${options[$default_idx]}"
    fi
}

# prompt_choose_many "Header" option1 option2 ...
prompt_choose_many() {
    local header="$1"
    shift
    local options=("$@")

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
        local selected=()
        local i
        for i in "${!options[@]}"; do
            [[ "${options[$i]}" == *"[default]"* ]] && selected+=("$i")
        done
        if [[ ${#selected[@]} -gt 0 ]]; then
            local args=()
            for i in "${selected[@]}"; do
                args+=(--selected "$i")
            done
            printf '%s\n' "${options[@]}" | gum choose --no-limit --header "$header" "${args[@]}"
        else
            printf '%s\n' "${options[@]}" | gum choose --no-limit --header "$header"
        fi
        return 0
    fi

    echo -e "${BackCyan}${header}${Off}"
    echo -e "${Yellow}Enter numbers separated by spaces (e.g. 1 3 4). Empty = defaults/all.${Off}"
    local i
    for i in "${!options[@]}"; do
        printf "  %d) %s\n" "$((i + 1))" "${options[$i]}"
    done
    local picks
    read -r -p "Choices: " picks
    if [[ -z "$picks" ]]; then
        local defaults=()
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
    local n
    for n in $picks; do
        if [[ "$n" =~ ^[0-9]+$ ]] && [[ "$n" -ge 1 && "$n" -le ${#options[@]} ]]; then
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
        echo -e "${Cyan}${title}${Off}"
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
