# OpenWrite command-line tools (SwiftPM release binaries).
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
CLI_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
BUILD_DIR := $(CLI_DIR).build/release

.PHONY: sync build install uninstall test-queries test-writing test-all query stats index

sync:
	@$(CLI_DIR)sync-core-sources.sh

build: sync
	@cd "$(CLI_DIR)" && swift build -c release

install: build
	@install -d "$(BINDIR)"
	@install -m 755 "$(BUILD_DIR)/openwrite" "$(BINDIR)/openwrite"
	@install -m 755 "$(BUILD_DIR)/openwrite-index" "$(BINDIR)/openwrite-index"
	@install -m 755 "$(BUILD_DIR)/openwrite-query" "$(BINDIR)/openwrite-query"
	@install -m 755 "$(BUILD_DIR)/openwrite-stats" "$(BINDIR)/openwrite-stats"
	@echo "Installed to $(BINDIR)"

uninstall:
	@rm -f "$(BINDIR)/openwrite" "$(BINDIR)/openwrite-index" \
		"$(BINDIR)/openwrite-query" "$(BINDIR)/openwrite-stats" \
		"$(BINDIR)/openwrite-cli"
	@echo "Removed OpenWrite CLI binaries from $(BINDIR)"

# Run from repo without installing (uses release build in .build/release).
RUN := $(BUILD_DIR)/openwrite

test-queries: build
	@$(RUN) test-queries --reindex

test-writing: build
	@$(RUN) test-writing

test-all: build
	@$(RUN) test-all --reindex

query: build
	@$(RUN) query $(ARGS)

stats: build
	@$(RUN) stats $(ARGS)

index: build
	@$(RUN) index $(ARGS)
