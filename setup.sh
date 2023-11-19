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
        echo "Homebrew is installed."

        # Ask the user if they want to update Homebrew
        read -p "Do you want to update Homebrew? (y/n): " update_brew
        if [[ $update_brew = [Yy]* ]]; then
            echo "Updating Homebrew..."
            brew update
            brew upgrade
        else
            echo "Skipping Homebrew update."
        fi
    else
        echo "Homebrew is not installed. Installing now..."
        # Install Homebrew
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
}

# Main script execution starts here
echo "Starting setup..."

# Install Xcode Command Line Tools
install-xcode-command-line-tools

# Install Homebrew
install_homebrew

echo "Setup complete!"
