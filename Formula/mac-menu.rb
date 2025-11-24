class MacMenu < Formula
  desc "A command line tool for Mac"
  homepage "https://github.com/sadiksaifi/mac-menu"
  url "https://github.com/sadiksaifi/mac-menu/releases/download/v0.1.0/mac-menu.tar.gz"
  sha256 "1862c17762cd9eafe1e420f1b59f00795e770ef50c50d02394e0159e70e2db77"
  license "MIT"

  def install
    bin.install "mac-menu"
  end

  test do
    system "#{bin}/mac-menu", "--help"
  end
end
