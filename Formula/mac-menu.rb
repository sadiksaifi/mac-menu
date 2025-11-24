class MacMenu < Formula
  desc "A command line tool for Mac"
  homepage "https://github.com/sadiksaifi/mac-menu"
  url "https://github.com/sadiksaifi/mac-menu/releases/download/v0.0.5/mac-menu.tar.gz"
  sha256 "ae93d08c423df31a611eda3c296e689b541fff4b1183a162dd1d217a2d8d30cd"
  license "MIT"

  def install
    bin.install "mac-menu"
  end

  test do
    system "#{bin}/mac-menu", "--help"
  end
end
