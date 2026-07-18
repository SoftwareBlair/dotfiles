#!/bin/bash
# Font catalog — Nerd Fonts (download-based for cross-platform reliability)

_register_nerd_font() {
    local id="$1"
    local name="$2"
    local brew_cask="$3"
    local release_name="$4"
    local description="$5"

    catalog_register "$id" \
        "name=$name" \
        "category=fonts" \
        "platforms=macos,linux" \
        "description=$description" \
        "check=test -d \"\$(font_dir)\" && ls \"\$(font_dir)\" 2>/dev/null | grep -qi \"$release_name\"" \
        "install_brew_macos=brew install --cask $brew_cask || install_nerd_font_download $release_name \"$name\"" \
        "install_brew_linux=brew install --cask $brew_cask || install_nerd_font_download $release_name \"$name\"" \
        "install_script=install_nerd_font_download $release_name \"$name\"" \
        "uninstall_brew=brew uninstall --cask $brew_cask || true; uninstall_nerd_font_download $release_name" \
        "uninstall_script=uninstall_nerd_font_download $release_name" \
        "install_dest_macos=~/Library/Fonts" \
        "install_dest_linux=~/.local/share/fonts" \
        "install_side_effects=fc-cache on Linux" \
        "install_requires_sudo=false" \
        "release_name=$release_name"
}

_register_nerd_font "sfmono_nerd" "SFMono Nerd Font" "font-sf-mono" "SFMono" "Personal favorite for code"
_register_nerd_font "hack_nerd" "Hack Nerd Font" "font-hack-nerd-font" "Hack" "Classic coding font with icons"
_register_nerd_font "firacode_nerd" "FiraCode Nerd Font" "font-fira-code-nerd-font" "FiraCode" "Ligatures for code"
_register_nerd_font "meslo_nerd" "Meslo Nerd Font" "font-meslo-lg-nerd-font" "Meslo" "Popular with Powerlevel10k"
_register_nerd_font "cascadia_nerd" "Cascadia Code Nerd Font" "font-caskaydia-cove-nerd-font" "CascadiaCode" "Microsoft Cascadia with Nerd glyphs"

install_nerd_font_download() {
    local release_name="$1"
    local name="${2:-$release_name Nerd Font}"
    local version="v3.3.0"
    local zip_url="https://github.com/ryanoasis/nerd-fonts/releases/download/${version}/${release_name}.zip"
    local dest
    dest="$(font_dir)"
    local cmd="mkdir -p \"$dest\" && curl -fsSL \"$zip_url\" -o /tmp/${release_name}.zip && unzip -o /tmp/${release_name}.zip -d \"$dest/${release_name}-nf\" && (command -v fc-cache >/dev/null && fc-cache -fv \"$dest\" || true)"

    if dry_run_is_active; then
        dry_run_add_step "$name" "$cmd" "$dest" "fc-cache on Linux" "false" ""
        return 0
    fi

    mkdir -p "$dest"
    local tmp
    tmp="$(mktemp -d)"
    if ! curl -fsSL "$zip_url" -o "$tmp/font.zip"; then
        prompt_error "Failed to download $release_name Nerd Font from $zip_url"
        rm -rf "$tmp"
        return 1
    fi
    unzip -o "$tmp/font.zip" -d "$dest/${release_name}-nf" >/dev/null
    rm -rf "$tmp"
    if command -v fc-cache >/dev/null; then
        fc-cache -fv "$dest" >/dev/null 2>&1 || true
    fi
    state_log_install "font_${release_name}" "$name" "install" \
        "download Nerd Font $release_name to $dest" "$dest" "fc-cache" "" "" ""
}

uninstall_nerd_font_download() {
    local release_name="$1"
    local dest
    dest="$(font_dir)"
    local cmd="rm -rf \"$dest/${release_name}-nf\"; find \"$dest\" -iname '*${release_name}*' -type f -delete 2>/dev/null; command -v fc-cache >/dev/null && fc-cache -fv \"$dest\" || true"
    if dry_run_is_active; then
        dry_run_add_step "Undo font: $release_name" "$cmd" "$dest" "fc-cache" "false" ""
        return 0
    fi
    rm -rf "$dest/${release_name}-nf" 2>/dev/null || true
    find "$dest" -iname "*${release_name}*" -type f -delete 2>/dev/null || true
    command -v fc-cache >/dev/null && fc-cache -fv "$dest" >/dev/null 2>&1 || true
}
