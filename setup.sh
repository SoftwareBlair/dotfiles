#!/bin/bash

# Function to install Xcode Command Line Tools if they're not already installed
install-xcode-command-line-tools() {
    echo "Checking for Xcode Command Line Tools..."
    if xcode-select -p &>/dev/null; then
        echo "Xcode Command Line Tools are already installed."
        
        # Ask the user if they want to check for software updates
        read -p "Do you want to check for software updates? (y/n): " answer
        if [[ $answer = [Yy]* ]]; then
            softwareupdate -ia --verbose
        else
            echo "Skipping software updates."
        fi
    else
        echo "Xcode Command Line Tools are not installed. Installing now..."
        # Install Xcode Command Line Tools
        xcode-select --install
    fi
}

# Function to install Homebrew if it's not already installed
install_homebrew() {
    if command -v brew &>/dev/null; then
        echo "Updating Homebrew..."
        brew update
        brew upgrade
    else
        echo "Homebrew is not installed. Installing now..."
        # Install Homebrew
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
}

install_nvm() {
    # If NVM is already installed, skip installation
    if command -v .nvm &>/dev/null; then
        echo "NVM is already installed."
    else
        echo "NVM is not installed. Installing now..."
        # Install NVM
        brew install nvm
        mkdir ~/.nvm

        nvm install node --lts
    fi
}

# Function to remove the git origin remote
# remove_git_origin_remote() {
#     echo "Removing the git origin remote is recommended so that you can use this repo as a template for your own dotfiles."
#     read -p "Do you want to remove the git origin remote? (y/n): " remove_git_origin
#     if [[ $remove_git_origin = [Yy]* ]]; then
#         echo "Removing git origin remote..."
#         git remote remove origin

#         # Ask the user if they want to add a new git origin remote
#         read -p "Do you want to add a new git origin remote? (y/n): " add_git_origin
#         if [[ $add_git_origin = [Yy]* ]]; then
#             read -p "Enter the URL of the new git origin remote: " git_origin_url
#             git remote add origin $git_origin_url
#         else
#             echo "Skipping git origin remote addition and deleting the .git directory..."
#             rm -rf .git
#         fi
#     else
#         echo "Skipping git origin remote removal."
#     fi
# }

# Find where dotfiles repo was cloned or downloaded
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Function to symlink dotfiles
symlink_dotfiles() {
    echo "Symlinking dotfiles is recommended so that you can easily update them."
    read -p "Do you want to symlink dotfiles? (y/n): " symlink
    if [[ $symlink = [Yy]* ]]; then
        echo "Symlinking dotfiles..."
        ln -s $DOTFILES_DIR/.zshrc ~/.zshrc
        ln -s $DOTFILES_DIR/.gitconfig ~/.gitconfig
    else
        echo "Skipping dotfile symlinking."
    fi
}

# Function to configure git
# configure_git() {
#     read -p "Do you want to set common git config values? (y/n): " git_config
#     if [[ $git_config = [Yy]* ]]; then
#         read -p "Enter your name: " git_name
#         read -p "Enter your email: " git_email
#         read -p "Enter your GitHub username: " git_username
#         read -p "Set VS Code as your preffered editor? (y/m): " git_editor
#         read -p "Set rebasing as default merge strategy? (y/n): " git_rebase

#         echo "Setting git config values..."
#         git config --global user.name "$git_name"
#         git config --global user.email "$git_email"
#         git config --global github.user "$git_username"
#         git config --global init.defaultBranch main

#         if [[ $git_editor = [Yy]* ]]; then
#             git config --global core.editor "code --wait"
#         fi

#         if [[ $git_rebase = [Yy]* ]]; then
#             git config --global pull.rebase true
#         fi
#     else
#         echo "Skipping git config."
#     fi
# }

# Main script execution starts here
echo "Starting setup..."

# Install Xcode Command Line Tools
install-xcode-command-line-tools

# Install Homebrew
install_homebrew

# Install NVM
# install_nvm

# Remove the git origin remote
# remove_git_origin_remote

# Symlink dotfiles
# symlink_dotfiles

# Configure git
# configure_git

# echo "Setup complete!"
