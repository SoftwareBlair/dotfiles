# Profiles

Community TOML profiles under [`profiles/`](../profiles/) remain available for contribution and tooling (`export_wizard_catalog`, validate), but the **main gum wizard does not require a profile step**.

Defaults live in [`.scripts/lib/presets.sh`](../.scripts/lib/presets.sh):

- **Shell (fixed):** zsh, starship, autosuggestions, syntax highlighting, eza, z, aliases  
- **Apps (picker):** editors, browsers, chat, CLI tools, etc.

## Built-in TOML files

- `default.toml` - minimal reference  
- `SoftwareBlair.toml` - example community package list  

Choosing packages interactively is the supported UX; profiles are optional metadata for contributors.
