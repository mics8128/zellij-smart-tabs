.PHONY: build build-dev test lint install clean dev dev-reload clean-cache version publish

PLUGIN_NAME = zellij-smart-tabs
WASM_TARGET = wasm32-wasip1
INSTALL_DIR = $(HOME)/.config/zellij/plugins
WASM_DEV = target/$(WASM_TARGET)/debug/$(PLUGIN_NAME).wasm
WASM_RELEASE = target/$(WASM_TARGET)/release/$(PLUGIN_NAME).wasm
VERSION = $(shell sed -n 's/^version = "\(.*\)"/\1/p' Cargo.toml | head -n 1)

build:
	cargo build --release --target $(WASM_TARGET)

build-dev:
	cargo build --target $(WASM_TARGET)

dev: clean-cache build-dev
	zellij -n dev-layout.kdl --session smart-tabs-dev

dev-reload: clean-cache build-dev
	zellij kill-session smart-tabs-dev 2>/dev/null; sleep 0.5; zellij -n dev-layout.kdl --session smart-tabs-dev

test:
	cargo test --target $$(rustc -vV | grep host | awk '{print $$2}')

lint:
	cargo clippy --target $$(rustc -vV | grep host | awk '{print $$2}') -- -D warnings

test-all: test lint build

install: build clean-cache
	mkdir -p $(INSTALL_DIR)
	cp target/$(WASM_TARGET)/release/$(PLUGIN_NAME).wasm $(INSTALL_DIR)/

clean:
	cargo clean

clean-cache:
	rm -rf ~/.cache/zellij

version:
	@echo $(VERSION)

publish:
	./scripts/publish.sh
