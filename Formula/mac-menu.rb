class MacMenu < Formula
  desc "A command line tool for Mac"
  homepage "https://github.com/sadiksaifi/mac-menu"
  url "https://github.com/sadiksaifi/mac-menu/releases/download/v0.0.3/mac-menu.tar.gz"
  sha256 "20722f8e888df5e6d8316c77c0af56e770a9ef7193a86241b80bf5689c61d688"
  license "MIT"

  def install
    bin.install "mac-menu"
  end

  test do
    system "#{bin}/mac-menu", "--help"
  end
end
