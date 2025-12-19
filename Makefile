PREFIX ?= /usr/local
BINARY_NAME = mac-menu
SRC_DIR = src
DIST_DIR = .build
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "unknown")
SOURCES = $(SRC_DIR)/FuzzyMatch.swift $(SRC_DIR)/main.swift $(SRC_DIR)/Version.swift

.PHONY: all clean install uninstall test run
RUN_CMD = $(DIST_DIR)/$(BINARY_NAME)

all: $(DIST_DIR)/$(BINARY_NAME)

build: all

$(DIST_DIR)/$(BINARY_NAME): $(SOURCES)
	@mkdir -p $(DIST_DIR)
	swiftc -O -o $(DIST_DIR)/$(BINARY_NAME) $(SOURCES) -framework Cocoa

$(SRC_DIR)/Version.swift:
	@echo 'let appVersion = "$(VERSION)"' > $(SRC_DIR)/Version.swift

install: $(DIST_DIR)/$(BINARY_NAME)
	@echo "Installing to $(PREFIX)/bin..."
	@mkdir -p $(PREFIX)/bin
	@cp $(DIST_DIR)/$(BINARY_NAME) $(PREFIX)/bin/
	@chmod 755 $(PREFIX)/bin/$(BINARY_NAME)

uninstall:
	@echo "Uninstalling from $(PREFIX)/bin..."
	@rm -f $(PREFIX)/bin/$(BINARY_NAME)

clean:
	@echo "Cleaning build files..."
	@rm -rf $(DIST_DIR)

test:
	@echo "Running Swift Testing suite..."
	@swift test --enable-swift-testing

run: build
	@$(RUN_CMD)
