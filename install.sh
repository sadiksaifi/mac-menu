#!/bin/bash

# Exit on error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}Installing Mac Menu...${NC}"

# Create temp directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Download the repository
echo "Downloading source code..."
curl -sSL https://github.com/sadiksaifi/mac-menu/archive/refs/heads/main.tar.gz | tar xz
cd mac-menu-main

# Build and install
echo "Building and installing..."
make
sudo make install

# Clean up
cd ..
rm -rf "$TEMP_DIR"

echo -e "${GREEN}Installation complete!${NC}"
echo "You can now use mac-menu by piping input to it:"
echo "echo -e \"Firefox\\nSafari\\nChrome\" | mac-menu" 