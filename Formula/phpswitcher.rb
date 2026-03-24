class Phpswitcher < Formula
  desc "CLI tool to manage and switch between multiple PHP versions"
  homepage "https://github.com/rawdreeg/phpswitcher"
  url "https://github.com/rawdreeg/phpswitcher/releases/download/v0.4.0-beta.1/phpswitcher.tar.gz"
  sha256 "23ed0e3f960fd762cb137dcfe9d4afce973698ea5ca7bef8a45e3885b6a2a91c"
  license "MIT"

  def install
    bin.install "bin/phpswitcher"
    share.install "phpswitcher-init.sh"
    share.install "phpswitcher-init.fish"
    bash_completion.install "phpswitcher-completion.sh" => "phpswitcher"
    fish_completion.install "phpswitcher-completion.fish" => "phpswitcher.fish"
  end

  def caveats
    <<~EOS
      To enable auto-switching, add the following to your shell profile:

      For Bash (~/.bashrc) or Zsh (~/.zshrc):
        source "#{opt_share}/phpswitcher-init.sh"

      For Fish (~/.config/fish/config.fish):
        source "#{opt_share}/phpswitcher-init.fish"
    EOS
  end

  test do
    assert_match "phpswitcher", shell_output("#{bin}/phpswitcher version")
  end
end
