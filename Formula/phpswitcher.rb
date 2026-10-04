class Phpswitcher < Formula
  desc "Manage and switch between multiple PHP versions"
  homepage "https://github.com/rawdreeg/phpswitcher"
  url "https://github.com/rawdreeg/phpswitcher/releases/download/v0.6.1/phpswitcher.tar.gz"
  version "0.6.1"
  sha256 "f4b08352b26535b5764e65fd850b9db7a3acc57cebed45b68878d95886351221"
  license "MIT"
  head "https://github.com/rawdreeg/phpswitcher.git", branch: "main"

  depends_on "curl" => :recommended

  def install
    bin.install "bin/phpswitcher"
    # Next to the binary so `phpswitcher version` can read it without ~/.phpswitcher.
    bin.install "VERSION" if File.exist?("VERSION")
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
    # The published 0.4.0 script reads $PHPSWITCHER_DIR/VERSION. Newer scripts
    # also accept a VERSION file next to the binary, which `install` places there.
    phpswitcher_dir = testpath/".phpswitcher"
    phpswitcher_dir.mkpath
    (phpswitcher_dir/"VERSION").write "#{version}\n"
    ENV["PHPSWITCHER_DIR"] = phpswitcher_dir
    assert_match version.to_s, shell_output("#{bin}/phpswitcher version")
  end
end
