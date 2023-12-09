#!/bin/bash

source .zsh/color-vars.zsh

# Function to install Xcode Command Line Tools if they're not already installed
install-xcode-command-line-tools() {
    echo -e "${BackBlue}Checking for Xcode Command Line Tools...${Off}"
    echo -e "\n"
    if xcode-select -p &>/dev/null; then
        echo -e "${Cyan}Xcode Command Line Tools are already installed.${Off}"
        
        # Ask the user if they want to check for software updates
        echo -e "${Purple}Do you want to check for software updates? (y/n): ${Off}"
        read answer
        if [[ $answer = [Yy]* ]]; then
            softwareupdate -ia --verbose
        else
            echo -e "${Yellow}Skipping software updates.${Off}"
            echo -e "========================================"
        fi
    else
        echo -e "${Blue}Xcode Command Line Tools are not installed. Installing now...${Off}"
        # Install Xcode Command Line Tools
        xcode-select --install
    fi
}

# Function to install Homebrew if it's not already installed
install_homebrew() {
    echo -e "\n"
    echo -e "${BackBlue}Checking for Homebrew...${Off}"
    echo -e "\n"
    if command -v brew &>/dev/null; then
        echo -e "${Cyan}Homebrew is already installed.${Off}"

        # Ask the user if they want to update Homebrew
        echo -e "${Purple}Do you want to update Homebrew? (y/n): ${Off}"
        read update_brew
        if [[ $update_brew = [Yy]* ]]; then
            echo -e "${Blue}Updating Homebrew...${Off}"
            brew update
            brew upgrade
        else
            echo -e "${Yellow}Skipping Homebrew update.${Off}"
            echo -e "========================================"
        fi
    else
        echo -e "${Blue}Homebrew is not installed. Installing now...${Off}"
        # Install Homebrew
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
}

# Function to remove the git origin remote
remove_git_origin_remote() {
    echo -e "\n"
    echo -e "${BackCyan}Removing the git origin remote is recommended so that you can use this repo as a template for your own dotfiles.${Off}"
    echo -e "****************************************"
    echo -e "\n"
    echo -e "${Red}Do you want to remove the git origin remote? (y/n): ${Off}"
    read remove_git_origin
    if [[ $remove_git_origin = [Yy]* ]]; then
        echo -e "${Blue}Removing the git origin remote...${Off}"
        git remote remove origin

        # Ask the user if they want to add a new git origin remote
        echo -e "${Green}Do you want to add a new git origin remote? (y/n): ${Off}"
        read add_git_origin
        if [[ $add_git_origin = [Yy]* ]]; then
            echo -e "${Blue}Adding a new git origin remote...${Off}"
            read git_origin_url
            git remote add origin $git_origin_url
        else
            echo -e "${Red}Skipping git origin remote addition and deleting the .git directory...${Off}"
            rm -rf .git
        fi
    else
        echo -e "${Yellow}Skipping git origin remote removal.${Off}"
        echo -e "========================================"
    fi
}

# Find where dotfiles repo was cloned or downloaded
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Function to symlink dotfiles
symlink_dotfiles() {
    echo -e "\n"
    echo -e "${BackPurple}Symlinking dotfiles is recommended so that you can easily update them.${Off}"
    echo -e "****************************************"
    echo -e "\n"

    echo -e "${Purple}Do you want to symlink dotfiles? (y/n): ${Off}"
    read symlink
    if [[ $symlink = [Yy]* ]]; then
        echo -e "${Blue}Symlinking dotfiles...${Off}"
        ln -s $DOTFILES_DIR/.zshrc ~/.zshrc
        ln -s $DOTFILES_DIR/.gitconfig ~/.gitconfig
    else
        echo -e "${Yellow}Skipping dotfile symlinking.${Off}"
        echo -e "========================================"
    fi
}

# Function to configure git
configure_git() {
    echo -e "\n"
    echo -e "${Red}Do you want to set common git config values? (y/n): ${Off}"
    read git_config
    if [[ $git_config = [Yy]* ]]; then
        read -p "Enter your name: " git_name
        read -p "Enter your email: " git_email
        read -p "Enter your GitHub username: " git_username
        read -p "Set VS Code as your preffered editor? (y/m): " git_editor
        read -p "Set rebasing as default merge strategy? (y/n): " git_rebase

        echo "Setting git config values..."
        git config --global user.name "$git_name"
        git config --global user.email "$git_email"
        git config --global github.user "$git_username"
        git config --global init.defaultBranch main

        if [[ $git_editor = [Yy]* ]]; then
            git config --global core.editor "code --wait"
        fi

        if [[ $git_rebase = [Yy]* ]]; then
            git config --global pull.rebase true
        fi
    else
        echo -e "${Yellow}Skipping git config.${Off}"
    fi
}

# Main script execution starts here

echo -e "${BrCyan} ___   _              _                     ___         _                            ${Off}"
echo -e "${BrCyan}(  _\`\( )_           ( )_ _                (  _\`\\      ( )_                       ${Off}"
echo -e "${BrCyan}| (_(_| ,_)  _ _ _ __| ,_(_) ___    __     | (_(_)_  __| ,_)_   _ _ _               ${Off}"
echo -e "${BrCyan}\`\\__ \\| |  /'_\` ( '__| | | /' _ \`\/'_ \`\\   \`\\__ \\ /'__\`| | ( ) ( ( '_\`\\ ${Off}"
echo -e "${BrCyan}( )_) | |_( (_| | |  | |_| | ( ) ( (_) |   ( )_) (  ___| |_| (_) | (_) ) _  _  _     ${Off}"
echo -e "${BrCyan}\`\\____\`\\__\`\\__,_(_)  \`\\__(_(_) (_\`\\__  |   \`\\____\`\\____\`\\__\`\\___/| ,__/'(_)(_)(_)${Off}"
echo -e "${BrCyan}                                 ( )_) |                         | |                 ${Off}"
echo -e "${BrCyan}                                  \\___/'                         (_)                ${Off}"
echo -e "\n"


# Install Xcode Command Line Tools
install-xcode-command-line-tools

# Install Homebrew
install_homebrew

# Remove the git origin remote
remove_git_origin_remote

# Symlink dotfiles
symlink_dotfiles

# Configure git
configure_git

echo -e "\n"
echo -e "========================================"
echo -e "${BackPurple}Setup complete!${Off}"
echo -e "========================================"
