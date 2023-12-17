#!/bin/bash

export DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null 2>&1 && pwd )"
source ../.zsh/colors.zsh

move_dotfiles() {
    echo -e "${BackCyan}Moving dotfiles to root...${Off}"

    if [[ $DOTFILES_DIR != $HOME/dotfiles ]]; then
        mv $DOTFILES_DIR $HOME
        DOTFILES_DIR=$HOME/dotfiles
    else
        echo -e "${Yellow}Dotfiles are already in home directory.${Off}"
    fi
}

remove_git_origin_remote() {
    echo -e "\n"
    echo -e "${BackCyan}Git Origin Remote${Off}"
    echo -e "${Red}Removing the git origin remote is recommended so that you can use this repo as a template for your own dotfiles.${Off}"

    echo -e "${Purple}Do you want to remove the git origin remote? (y/n): ${Off}"
    read remove_git_origin
    if [[ $remove_git_origin = [Yy]* ]]; then
        echo -e "${Blue}Removing the git origin remote...${Off}"
        git remote remove origin

        echo -e "${Green}Do you want to add a new git origin remote? (y/n): ${Off}"
        read add_git_origin
        if [[ $add_git_origin = [Yy]* ]]; then
            echo -e "${Blue}Adding a new git origin remote...${Off}"
            read git_origin_url
            git remote add origin $git_origin_url
        else
            echo -e "${Yellow}Skipping git origin remote addition and deleting the .git directory...${Off}"
            rm -rf .git
        fi
    else
        echo -e "${Yellow}Skipping git origin remote removal.${Off}"
    fi
}

symlink_dotfile() {
    echo -e "${BrMagenta}Linking $1...${Off}"
    ln -sf $DOTFILES_DIR/$1 $HOME/$1
}

unlink_dotfile() {
    echo -e "${BrMagenta}Unlinking $1...${Off}"
    unlink $HOME/$1
}

uninstall_nvm() {
    echo -e "${BackCyan}Uninstalling NVM...${Off}"
    brew uninstall nvm
    rm -rf $HOME/.nvm
    rm -rf $HOME/.npm
}

revert_setup() {
    echo -e "\n"
    echo -e "${BackCyan}Revert Setup${Off}"
    echo -e "${Red}Reverting setup is recommended if you want to undo the changes made by setup.sh.${Off}"
    echo -e "${Red}This will uninstall NVM, unlink dotfiles, uninstall Homebrew, and remove the .nvm and .npm directories. You will need to manually delete the .gitconfig file and Xcode Command Line Tools.${Off}"

    echo -e "${Purple}Do you want to revert setup? (y/n): ${Off}"
    read revert_setup
    if [[ $revert_setup = [Yy]* ]]; then
        echo -e "${Blue}Reverting setup...${Off}"
        uninstall_nvm
        unlink_dotfile ".zshrc"
        unlink_dotfile ".config"
        unlink_dotfile ".warp"
        rm $HOME/.zprofile
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
    fi
}
