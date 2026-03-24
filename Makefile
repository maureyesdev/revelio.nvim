NVIM        := nvim
PLENARY_URL := https://github.com/nvim-lua/plenary.nvim
PLENARY_DIR := /tmp/plenary.nvim

.PHONY: test test-setup lint

## Install test dependencies (plenary.nvim)
test-setup:
	@if [ ! -d "$(PLENARY_DIR)" ]; then \
		echo "Cloning plenary.nvim..."; \
		git clone --depth 1 $(PLENARY_URL) $(PLENARY_DIR); \
	else \
		echo "plenary.nvim already present at $(PLENARY_DIR)"; \
	fi

## Run all unit tests
test: test-setup
	$(NVIM) \
		--headless \
		--noplugin \
		-u tests/minimal_init.lua \
		-c "set rtp+=$(PLENARY_DIR)" \
		-c "lua require('plenary.test_harness').test_directory('tests/unit', { minimal_init = 'tests/minimal_init.lua' })" \
		-c "qa!"

## Lint with stylua (requires stylua in PATH)
lint:
	@if command -v stylua >/dev/null 2>&1; then \
		stylua --check lua/ tests/; \
	else \
		echo "stylua not found — skipping lint"; \
	fi
