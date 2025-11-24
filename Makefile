PREFIX ?= /usr/local
BINARY_NAME = mac-menu
SRC_DIR = src
DIST_DIR = .build

.PHONY: all clean install uninstall test

all: $(DIST_DIR)/$(BINARY_NAME)

build: all

$(DIST_DIR)/$(BINARY_NAME): $(SRC_DIR)/main.swift
	@mkdir -p $(DIST_DIR)
	swiftc -O -o $(DIST_DIR)/$(BINARY_NAME) $(SRC_DIR)/main.swift -framework Cocoa

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

test: $(DIST_DIR)/$(BINARY_NAME)
	@echo "Testing with Yes/No input..."
	@echo "Yes\nNo" | $(DIST_DIR)/$(BINARY_NAME) 