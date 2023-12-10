#!/bin/bash

source .zsh/color-vars.zsh

DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

move_dotfiles() {
    echo -e "${BackBlue}Moving dotfiles to root...${Off}"
    echo -e "${Red}Moving dotfiles to root is recommended so that you can easily update them.${Off}"

    echo -e "${Purple}Do you want to move dotfiles to root? (y/n): ${Off}"
    read move_dotfiles
    if [[ $move_dotfiles = [Yy]* ]]; then
        if [[ $DOTFILES_DIR != $HOME/dotfiles ]]; then
            mv $DOTFILES_DIR $HOME
            DOTFILES_DIR=$HOME/dotfiles
        else
            echo -e "${Yellow}Dotfiles are already in home directory.${Off}"
        fi
    else
        echo -e "${Yellow}Skipping dotfile move.${Off}"
    fi
}

install_xcode_command_line_tools() {
    echo -e "${BackBlue}Checking for Xcode Command Line Tools...${Off}"
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
        xcode-select --install
    fi
}

install_homebrew() {
    echo -e "\n"
    echo -e "${BackBlue}Checking for Homebrew...${Off}"
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
    fi
}

install_nvm() {
    echo -e "\n"
    echo -e "${BackBlue}Checking for NVM...${Off}"

    source $(brew --prefix nvm)/nvm.sh
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
        source $(brew --prefix nvm)/nvm.sh

        if [ ! -d ~/.nvm ]; then
            echo -e "${Blue}Creating .nvm directory...${Off}"
            mkdir ~/.nvm
        fi

        echo -e "${Blue}Installing Node...${Off}"
        nvm install --lts

        echo -e "${Blue}Linking NVM...${Off}"
        ln -s $(brew --prefix nvm)/nvm.sh ~/.nvm/nvm.sh
        ln -s $(brew --prefix nvm)/nvm-exec ~/.nvm/nvm-exec
    fi
}

remove_git_origin_remote() {
    echo -e "\n"
    echo -e "${BackBlue}Git Origin Remote${Off}"
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

configure_git() {
    echo -e "\n"
    echo -e "${BackBlue}Git Configuration${Off}"
    echo -e "${Purple}Do you want to set common git config values? (y/n): ${Off}"
    read git_config
    if [[ $git_config = [Yy]* ]]; then
        read -p "Enter your name: " git_name
        read -p "Enter your email: " git_email
        read -p "Set VS Code as your preffered editor? (y/m): " git_editor
        read -p "Set rebasing as default merge strategy? (y/n): " git_rebase

        echo "Setting git config values..."
        git config --global user.name "$git_name"
        git config --global user.email "$git_email"
        git config --global init.defaultBranch main

        if [[ $git_editor = [Yy]* ]]; then
            if command -v code &>/dev/null; then
                git config --global core.editor "code --wait"
            else
                echo -e "${Red}VS Code is not installed.${Off}"
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
    echo -e "${BackBlue}Symlink Dotfile${Off}"
    echo -e "${Red}Symlinking dotfiles is recommended so that you can easily update them.${Off}"

    echo -e "${Purple}Do you want to symlink dotfiles? (y/n): ${Off}"
    read symlink
    if [[ $symlink = [Yy]* ]]; then
        echo -e "${Blue}Symlinking dotfiles...${Off}"
        ln -s $DOTFILES_DIR/.zshrc ~/.zshrc
        ln -s $DOTFILES_DIR/.gitconfig ~/.gitconfig
    else
        echo -e "${Yellow}Skipping dotfile symlinking.${Off}"
    fi
}

# Main script execution starts here

# Run a single command with the -c flag ./setup.sh -c [command]
if [[ $1 = "-c" ]]; then
    $2
    echo -e "\n"
    echo -e "${BackCyan}Command complete!${Off}"
    echo -e "\n"
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
    install_nvm
    remove_git_origin_remote
    configure_git
    symlink_dotfiles

    echo -e "\n"
    echo -e "${BackCyan}Setup complete!${Off}"
    echo -e "\n"
fi
