class MacMenu < Formula
  desc "A command line tool for Mac"
  homepage "https://github.com/sadiksaifi/mac-menu"
  url "https://github.com/sadiksaifi/mac-menu/releases/download/v0.0.4/mac-menu.tar.gz"
  sha256 "6a89c37e33bdebf37e426ee7440bc4de61f926d4f92db807185a747e22a14b7d"
  license "MIT"

  def install
    bin.install "mac-menu"
  end

  test do
    system "#{bin}/mac-menu", "--help"
  end
end
