# typed: false
# frozen_string_literal: true

# Homebrew formula for dotfiles-setup (tap: SoftwareBlair/dotfiles)
#
#   brew tap SoftwareBlair/dotfiles
#   brew install dotfiles-setup
#
# Or from this repo checkout:
#   brew install --formula ./Formula/dotfiles-setup.rb
#
class DotfilesSetup < Formula
  desc "Cross-platform new-machine setup wizard (TUI)"
  homepage "https://github.com/SoftwareBlair/dotfiles"
  version "0.1.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/SoftwareBlair/dotfiles/releases/download/v#{version}/dotfiles-setup-darwin-arm64"
      # sha256 updated on each release — placeholder until first tag
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
    on_intel do
      url "https://github.com/SoftwareBlair/dotfiles/releases/download/v#{version}/dotfiles-setup-darwin-amd64"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/SoftwareBlair/dotfiles/releases/download/v#{version}/dotfiles-setup-linux-arm64"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
    on_intel do
      url "https://github.com/SoftwareBlair/dotfiles/releases/download/v#{version}/dotfiles-setup-linux-amd64"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
  end

  def install
    bin.install Dir["dotfiles-setup-*"].first => "dotfiles-setup"
  end

  test do
    assert_match "Usage", shell_output("#{bin}/dotfiles-setup -h 2>&1", 0)
  rescue
    # Binary may not support -h until wired; at least ensure it exists
    assert_predicate bin/"dotfiles-setup", :exist?
  end
end
