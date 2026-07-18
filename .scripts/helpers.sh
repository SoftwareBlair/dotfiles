#!/bin/bash

export DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null 2>&1 && pwd )"

# Colors may already be sourced by setup.sh
if [[ -z "${Off:-}" ]]; then
    # shellcheck disable=SC1091
    source "$DOTFILES_DIR/.zsh/colors.zsh"
fi

move_dotfiles() {
    echo -e "${BackCyan}Moving dotfiles to ~/dotfiles (optional)...${Off}"

    if [[ "$DOTFILES_DIR" != "$HOME/dotfiles" ]]; then
        if dry_run_is_active 2>/dev/null; then
            dry_run_add_step "move_dotfiles" "mv $DOTFILES_DIR $HOME/dotfiles" "$HOME/dotfiles" "" "false" ""
            return 0
        fi
        mv "$DOTFILES_DIR" "$HOME/dotfiles"
        DOTFILES_DIR="$HOME/dotfiles"
        echo -e "${Green}Moved to $HOME/dotfiles${Off}"
        echo -e "${Cyan}Tip: setup also works from any path without moving.${Off}"
    else
        echo -e "${Yellow}Dotfiles are already in ~/dotfiles.${Off}"
    fi
}

remove_git_origin_remote() {
    echo -e "\n"
    echo -e "${BackCyan}Git Origin Remote${Off}"
    echo -e "${Red}Removing the git origin remote is recommended so that you can use this repo as a template for your own dotfiles.${Off}"

    if prompt_confirm "Do you want to remove the git origin remote?" 2>/dev/null; then
        :
    else
        echo -e "${Purple}Do you want to remove the git origin remote? (y/n): ${Off}"
        read -r remove_git_origin
        [[ "$remove_git_origin" = [Yy]* ]] || { echo -e "${Yellow}Skipping.${Off}"; return 0; }
    fi

    echo -e "${Blue}Removing the git origin remote...${Off}"
    git -C "$DOTFILES_DIR" remote remove origin 2>/dev/null || true

    echo -e "${Green}Do you want to add a new git origin remote? (y/n): ${Off}"
    read -r add_git_origin
    if [[ "$add_git_origin" = [Yy]* ]]; then
        echo -e "${Blue}Adding a new git origin remote...${Off}"
        read -r git_origin_url
        git -C "$DOTFILES_DIR" remote add origin "$git_origin_url"
    else
        echo -e "${Yellow}Skipping git origin remote addition.${Off}"
    fi
}

symlink_dotfile() {
    local rel="$1"
    if declare -f symlink_dotfile_safe >/dev/null 2>&1; then
        symlink_dotfile_safe "$rel"
        return
    fi
    echo -e "${BrMagenta}Linking $rel...${Off}"
    ln -sfn "$DOTFILES_DIR/$rel" "$HOME/$rel"
}

unlink_dotfile() {
    echo -e "${BrMagenta}Unlinking $1...${Off}"
    unlink "$HOME/$1" 2>/dev/null || true
}

uninstall_nvm() {
    echo -e "${BackCyan}Uninstalling NVM...${Off}"
    if declare -f uninstall_nvm_official >/dev/null 2>&1; then
        uninstall_nvm_official
        return
    fi
    rm -rf "$HOME/.nvm" "$HOME/.npm"
    if command -v brew &>/dev/null && brew list nvm &>/dev/null 2>&1; then
        brew uninstall nvm || true
    fi
}

# Backward compatible: delegates to log-driven undo
revert_setup() {
    if declare -f run_undo >/dev/null 2>&1; then
        run_undo "false"
        return
    fi
    echo -e "${Red}Undo library not loaded. Run: ./setup.sh --undo${Off}"
    return 1
}
