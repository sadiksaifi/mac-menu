class MacMenu < Formula
  desc "A command line tool for Mac"
  homepage "https://github.com/sadiksaifi/mac-menu"
  url "https://github.com/sadiksaifi/mac-menu/releases/download/v0.0.1/mac-menu.tar.gz" # Placeholder
  sha256 "REPLACE_WITH_SHA256"
  license "MIT"

  def install
    bin.install "mac-menu"
  end

  test do
    system "#{bin}/mac-menu", "--help"
  end
end
