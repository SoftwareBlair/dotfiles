# FAQ

## Is this just Blair’s personal dotfiles?

No. **dotfiles-setup** is a general setup tool. The **Default** profile is the common path. `SoftwareBlair` is one optional community profile (packages + themes), the same way anyone can contribute theirs.

## Will it overwrite my `.zshrc`?

Setup regenerates `~/.zshrc` / `~/.zshenv` and modules under `~/.dotfiles-setup/generated/`. Existing files are backed up first. Put personal customizations in **`~/.zshrc.local`** (never overwritten). Migration can also backup unmanaged configs.

## Why don’t I get every alias / plugin?

Shell pieces are **opt-in**. Only selected modules are generated. Profiles pre-check defaults; you can clear them in the wizard.

## How do I migrate from an older clone of this repo?

Run the wizard; if old symlinks or prior state are detected, choose **Upgrade** or **Adopt**. Dry-run first with `-n`.

## Windows?

Not supported in this version (macOS and Linux only).

## Where is state stored?

`~/.dotfiles-setup/` — see [architecture](architecture.md).

## How do I undo?

`./.scripts/setup.sh --undo` (preview with `-n`).
