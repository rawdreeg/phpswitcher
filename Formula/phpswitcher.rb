class Phpswitcher < Formula
  desc "Manage and switch between multiple PHP versions"
  homepage "https://github.com/rawdreeg/phpswitcher"
  url "https://github.com/rawdreeg/phpswitcher/releases/download/v0.4.0-beta.1/phpswitcher.tar.gz"
  version "0.4.0-beta.1"
  sha256 "23ed0e3f960fd762cb137dcfe9d4afce973698ea5ca7bef8a45e3885b6a2a91c"
  license "MIT"
  head "https://github.com/rawdreeg/phpswitcher.git", branch: "main"

  depends_on "curl" => :recommended

  def install
    bin.install "bin/phpswitcher"
    pkgshare.install "phpswitcher-init.sh"
    pkgshare.install "phpswitcher-init.fish"
    bash_completion.install "phpswitcher-completion.sh" => "phpswitcher"
    fish_completion.install "phpswitcher-completion.fish" => "phpswitcher.fish"
  end

  def caveats
    <<~EOS
      To enable automatic PHP version switching, add to your shell profile:

      Bash (~/.bashrc) or Zsh (~/.zshrc):
        source "#{opt_pkgshare}/phpswitcher-init.sh"

      Fish (~/.config/fish/config.fish):
        source "#{opt_pkgshare}/phpswitcher-init.fish"
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/phpswitcher version")
  end
end
