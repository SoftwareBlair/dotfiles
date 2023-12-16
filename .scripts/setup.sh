#!/bin/bash

source ./helpers.sh
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

install_xcode_command_line_tools() {
    echo -e "${BackCyan}Checking for Xcode Command Line Tools...${Off}"
    if xcode-select -p &>/dev/null; then
        echo -e "${Cyan}Xcode Command Line Tools are already installed.${Off}"
        
        echo -e "${Purple}Do you want to check for software updates? (y/n): ${Off}"
        read answer
        if [[ $answer = [Yy]* ]]; then
            softwareupdate -ia --verbose
        else
            echo -e "${Yellow}Skipping software updates.${Off}"
        fi
    else
        echo -e "${Blue}Xcode Command Line Tools are not installed. Installing now...${Off}"
        sudo xcode-select --install
    fi
}

install_homebrew() {
    echo -e "\n"
    echo -e "${BackCyan}Checking for Homebrew...${Off}"
    if command -v brew &>/dev/null; then
        echo -e "${Cyan}Homebrew is already installed.${Off}"

        echo -e "${Purple}Do you want to update Homebrew? (y/n): ${Off}"
        read update_brew
        if [[ $update_brew = [Yy]* ]]; then
            echo -e "${Blue}Updating Homebrew...${Off}"
            brew update
            brew upgrade
        else
            echo -e "${Yellow}Skipping Homebrew update.${Off}"
        fi
    else
        echo -e "${Blue}Homebrew is not installed. Installing now...${Off}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        (echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
}

configure_git() {
    echo -e "\n"
    echo -e "${BackCyan}Git Configuration${Off}"
    echo -e "${Purple}Do you want to set common git config values? (y/n): ${Off}"
    read git_config
    if [[ $git_config = [Yy]* ]]; then
            if [ -f ~/.gitconfig ]; then
                echo -e "${Cyan}Git config already exists.${Off}"

                echo -e "${Purple}Do you want to overwrite your git config? (y/n): ${Off}"
                read overwrite_git_config
                if [[ $overwrite_git_config = [Yy]* ]]; then
                    echo -e "${Blue}Overwriting git config...${Off}"
                    rm ~/.gitconfig
                    touch ~/.gitconfig
                else
                    echo -e "${Yellow}Skipping git config overwrite.${Off}"
                fi
            else
                echo -e "${Blue}Creating git config...${Off}"
                touch ~/.gitconfig
            fi
        read -p "Enter your name: " git_name
        read -p "Enter your email: " git_email
        read -p "Set VS Code as your preffered editor? (y/n): " git_editor
        read -p "Set rebasing as default merge strategy? (y/n): " git_rebase

        echo "Setting git config values..."
        git config --global user.name "$git_name"
        git config --global user.email "$git_email"
        git config --global init.defaultBranch main
        git config --global filter.lfs.clean "git-lfs clean -- %f"
        git config --global filter.lfs.smudge "git-lfs smudge -- %f"
        git config --global filter.lfs.process "git-lfs filter-process"
        git config --global filter.lfs.required true
        git config --global alias.hist "log --pretty=format:\"%h %ad | %s%d [%an]\" --graph --date=short"

        if [[ $git_editor = [Yy]* ]]; then
            if command -v code &>/dev/null; then
                git config --global core.editor "code --wait"
            else
                echo -e "${Red}VS Code is not installed.${Off}"
                echo -e "${Purple}Do you want to install VS Code? (y/n): ${Off}"
                read install_vscode
                if [[ $install_vscode = [Yy]* ]]; then
                    echo -e "${Blue}Installing VS Code...${Off}"
                    brew install --cask visual-studio-code
                    git config --global core.editor "code --wait"
                else
                    echo -e "${Yellow}Skipping VS Code installation.${Off}"
                fi
            fi
        fi

        if [[ $git_rebase = [Yy]* ]]; then
            git config --global pull.rebase true
        fi
    else
        echo -e "${Yellow}Skipping git config.${Off}"
    fi
}

symlink_dotfiles() {
    echo -e "\n"
    echo -e "${BackCyan}Symlink Dotfile${Off}"
    echo -e "${Red}Symlinking dotfiles is recommended so that you can easily update them.${Off}"

    echo -e "${Purple}Do you want to symlink dotfiles? (y/n): ${Off}"
    read symlink
    if [[ $symlink = [Yy]* ]]; then
        echo -e "${Blue}Symlinking dotfiles...${Off}"
        symlink ".zshrc"
        symlink ".config"
        symlink ".warp"
    else
        echo -e "${Yellow}Skipping dotfile symlinking.${Off}"
    fi
}

install_nvm() {
    echo -e "\n"
    echo -e "${BackCyan}Checking for NVM...${Off}"

    if type nvm &>/dev/null; then
        echo -e "${Cyan}NVM is already installed.${Off}"

        echo -e "${Purple}Do you want to update NVM? (y/n): ${Off}"
        read update_nvm
        if [[ $update_nvm = [Yy]* ]]; then
            echo -e "${Blue}Updating NVM...${Off}"
            brew upgrade nvm
        else
            echo -e "${Yellow}Skipping NVM update.${Off}"
        fi
    else
        echo -e "${Blue}NVM is not installed. Installing now...${Off}"
        brew install nvm

        if [ ! -d ~/.nvm ]; then
            echo -e "${Blue}Creating .nvm directory...${Off}"
            mkdir ~/.nvm
        fi

        source $(brew --prefix nvm)/nvm.sh

        echo -e "${Blue}Installing Node LTS...${Off}"
        nvm install --lts
        nvm alias default lts/*
    fi
}

# Main script execution starts here

# Run a single command with the -c flag ./setup.sh -c [command]
if [[ $1 = "-c" ]]; then
    $2
    echo -e "\n"
    echo -e "${BackCyan}Command complete!${Off}"
    echo -e "\n"

    source $HOME/dotfiles/.zshrc
else
    echo -e "${BrCyan} ___   _              _                     ___         _                            ${Off}"
    echo -e "${BrCyan}(  _\`\( )_           ( )_ _                (  _\`\\      ( )_                       ${Off}"
    echo -e "${BrCyan}| (_(_| ,_)  _ _ _ __| ,_(_) ___    __     | (_(_)_  __| ,_)_   _ _ _               ${Off}"
    echo -e "${BrCyan}\`\\__ \\| |  /'_\` ( '__| | | /' _ \`\/'_ \`\\   \`\\__ \\ /'__\`| | ( ) ( ( '_\`\\ ${Off}"
    echo -e "${BrCyan}( )_) | |_( (_| | |  | |_| | ( ) ( (_) |   ( )_) (  ___| |_| (_) | (_) ) _  _  _     ${Off}"
    echo -e "${BrCyan}\`\\____\`\\__\`\\__,_(_)  \`\\__(_(_) (_\`\\__  |   \`\\____\`\\____\`\\__\`\\___/| ,__/'(_)(_)(_)${Off}"
    echo -e "${BrCyan}                                 ( )_) |                         | |                 ${Off}"
    echo -e "${BrCyan}                                  \\___/'                         (_)                ${Off}"
    echo -e "\n"

    move_dotfiles
    install_xcode_command_line_tools
    install_homebrew
    configure_git
    symlink_dotfiles
    install_nvm

    source $HOME/dotfiles/.zshrc

    echo -e "\n"
    echo -e "${BackCyan}Setup complete!${Off}"
    echo -e "\n"
fi
