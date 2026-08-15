#!/bin/bash
# Font catalog — SFMono Nerd Font (patched + ligaturized)

catalog_register "sfmono_nerd" \
    "name=SFMono Nerd Font" \
    "category=fonts" \
    "platforms=macos,linux" \
    "description=Personal favorite for code (Nerd Font + ligatures)" \
    "check=test -d \"\$(font_dir)\" && ls \"\$(font_dir)\" 2>/dev/null | grep -qiE 'SFMono|Liga.?SFMono'" \
    "install_script=install_sfmono_nerd_font" \
    "uninstall_script=uninstall_sfmono_nerd_font" \
    "upgrade_script=install_sfmono_nerd_font" \
    "upgrade_offer=always" \
    "install_dest_macos=~/Library/Fonts/SFMono-Nerd-Font" \
    "install_dest_linux=~/.local/share/fonts/SFMono-Nerd-Font" \
    "install_side_effects=fc-cache on Linux" \
    "install_requires_sudo=false"

# Apple SF Mono patched with Nerd Font glyphs + ligatures
# https://github.com/shaunsingh/SFMono-Nerd-Font-Ligaturized
install_sfmono_nerd_font() {
    local name="SFMono Nerd Font"
    local dest
    dest="$(font_dir)/SFMono-Nerd-Font"
    local repo="https://github.com/shaunsingh/SFMono-Nerd-Font-Ligaturized.git"
    local cmd="git clone --depth 1 $repo /tmp/sfmono-nf && mkdir -p \"$dest\" && find /tmp/sfmono-nf -iname '*.otf' -exec cp {} \"$dest/\" \\; && (command -v fc-cache >/dev/null && fc-cache -fv \"$dest\" || true)"

    if dry_run_is_active; then
        dry_run_add_step "$name" "$cmd" "$dest" "fc-cache on Linux" "false" ""
        return 0
    fi

    local tmp
    tmp="$(mktemp -d)"
    if ! git clone --depth 1 "$repo" "$tmp/repo" 2>/dev/null; then
        prompt_error "Failed to clone SFMono Nerd Font from $repo"
        rm -rf "$tmp"
        return 1
    fi
    mkdir -p "$dest"
    find "$tmp/repo" -iname '*.otf' -exec cp {} "$dest/" \;
    rm -rf "$tmp"
    if command -v fc-cache >/dev/null; then
        fc-cache -fv "$dest" >/dev/null 2>&1 || true
    fi
    state_log_install "sfmono_nerd" "$name" "install" \
        "clone SFMono Nerd Font Ligaturized to $dest" "$dest" "fc-cache" "" "" ""
}

uninstall_sfmono_nerd_font() {
    local dest
    dest="$(font_dir)/SFMono-Nerd-Font"
    local cmd="rm -rf \"$dest\"; find \"\$(font_dir)\" -iname '*SFMono*' -type f -delete 2>/dev/null; command -v fc-cache >/dev/null && fc-cache -fv \"\$(font_dir)\" || true"
    if dry_run_is_active; then
        dry_run_add_step "Undo font: SFMono" "$cmd" "$dest" "fc-cache" "false" ""
        return 0
    fi
    rm -rf "$dest" 2>/dev/null || true
    find "$(font_dir)" -iname '*SFMono*' -type f -delete 2>/dev/null || true
    command -v fc-cache >/dev/null && fc-cache -fv "$(font_dir)" >/dev/null 2>&1 || true
}
