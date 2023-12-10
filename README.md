# Dotfiles for Mac

## Introduction

This repository contains my personal dotfiles tailored for zsh and a setup.sh script to automate the setup process of a new macOS system or update an existing one with my default configuration.

## Installation

You can install these dotfiles by either cloning the repository or downloading it as a ZIP file.

### Method 1: Cloning the Repository
1. Clone the Repository:

    Open the Terminal and run:
    ```
    git clone https://github.com/SoftwareBlair/dotfiles.git
    cd dotfiles
    ```
2. Run the Setup Script:
    
    This script will set up your environment using these dotfiles.
    ```
    chmod +x setup.sh
    ./setup.sh
    ```
    Follow any on-screen prompts.

### Method 2: Downloading ZIP File
1. Download the ZIP File:
     - Click on Code and select Download ZIP.
     - Extract the ZIP file to your preferred location.
2. Run the Setup Script:
    
    In the Terminal, navigate to the extracted folder and execute:
    ```
    cd path/to/dotfiles
    chmod +x setup.sh
    ./setup.sh
    ```
    Replace `path/to/dotfiles` with the actual path.

## Running Specific Commands from setup.sh

The `setup.sh` script in this repository is designed for versatility, allowing you to run specific parts of the setup process individually. This can be particularly useful if you want to execute only a certain function without going through the entire script.

### Usage
To run a specific command, use the -c flag followed by the command name. Here's the syntax:

```
./setup.sh -c [command_name]
```

### Available Commands
List the commands available for individual execution. For instance:
- `move_dotfiles`
- `install_xcode_command_line_tools`
- `install_homebrew`
- `remove_git_origin_remote`
- `configure_git`
- `symlink_dotfiles`

### Use Cases
- Selective Execution: Run specific parts of the script as needed, without executing the entire setup.
- Testing and Debugging: Test individual functions of the script to ensure they work correctly or to debug them.

## Contributing

Feel free to contribute to this repository. Your suggestions and improvements are welcome. Please follow the standard fork, branch, and pull request workflow.

## License

This project is open-sourced under the MIT License. See the [LICENSE](LICENSE) file for more details.
