# Dotfiles for Mac

## Introduction

This repository contains my personal dotfiles tailored for zsh and a setup.sh script to automate the setup process of a new macOS system.

## Installation

You can install these dotfiles by either cloning the repository or downloading it as a ZIP file.

### Method 1: Cloning the Repository

Open the Terminal and run from root:
```
git clone https://github.com/SoftwareBlair/dotfiles.git
```

### Method 2: Downloading ZIP File

Download the ZIP File:
- Click on Code and select Download ZIP.
- Extract the ZIP file to root.
    - You may have to rename the extracted directory to dotfiles

### Run the Setup Script
    
In the Terminal
```
cd ~/dotfiles/.scripts
chmod +x setup.sh
./setup.sh
```

> If the dotfiles is not in root, run `./setup.sh -c move_dotfiles` from the scripts directory

## Running Specific Commands from setup.sh

The `setup.sh` script in this repository is designed for versatility, allowing you to run specific parts of the setup process individually. This can be particularly useful if you want to execute only a certain function without going through the entire script.

### Usage

To run a specific command, use the -c flag followed by the command name.

```
./setup.sh -c [command_name]
```

### Available Commands

#### Primary Commands

- `install_xcode_command_line_tools`
- `install_homebrew`
- `configure_git`
- `symlink_dotfiles`
- `install_nvm`

#### Helpers

- `move_dotfiles`
- `remove_git_origin_remote`
- `symlink_dotfile`
- `unlink_dotfile`
- `uninstall_nvm`
- `revert_setup`

### Use Cases

- Selective Execution: Run specific parts of the script as needed, without executing the entire setup.
- Testing and Debugging: Test individual functions of the script to ensure they work correctly or to debug them.

## Contributing

Feel free to contribute to this repository. Your suggestions and improvements are welcome. Please follow the standard fork, branch, and pull request workflow.

## License

This project is open-sourced under the MIT License. See the [LICENSE](LICENSE) file for more details.
