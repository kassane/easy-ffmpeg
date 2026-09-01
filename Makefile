# Makefile — easy-ffmpeg build orchestration
#
# Bootstrap chain: build.carbon → ./build → ./build --output=easy-ffmpeg
# If build.carbon OR its dependencies change, Make rebuilds ./build FIRST.

# Auto-detect carbon toolchain:
# 1. Vendored carbon_toolchain-*/bin/carbon (newest by version sort)
# 2. $PATH fallback (system-installed carbon)
CARBON := $(shell ls -d carbon_toolchain-*/bin/carbon 2>/dev/null | sort -V | tail -1)
ifeq ($(CARBON),)
  CARBON := $(shell command -v carbon 2>/dev/null)
endif

# Fail fast if no toolchain found
ifeq ($(CARBON),)
  $(error No carbon toolchain found. Install vendored (carbon_toolchain-*) or add carbon to $$PATH)
endif

# Sources
BUILD_SRC := build.carbon
BUILD_DEPS := src/core/ArgsBuilder.carbon src/core/Constants.carbon src/core/ffi_helper.hpp
ALL_SRC := src/main.carbon src/core/*.carbon src/cli/*.carbon
ALL_HPP := src/core/ffi_helper.hpp

# Targets
BIN := easy-ffmpeg
BUILD_BIN := build

.PHONY: all clean format fmt docs check ci once help

all: $(BIN)

# Bootstrap: compile build.carbon → ./build
$(BUILD_BIN): $(BUILD_SRC) $(BUILD_DEPS)
	$(CARBON) build $(BUILD_SRC) src/core/*.carbon --output=$(BUILD_BIN) -- -std=c++23 -Isrc/core

# Main binary: delegate to ./build (now guaranteed up-to-date)
$(BIN): $(BUILD_BIN) $(ALL_SRC)
	./$(BUILD_BIN) --output=$(BIN)

clean:
	-rm -f $(BIN) $(BUILD_BIN)

format:
	$(CARBON) format $(ALL_SRC)

clang-format:
	clang-format -i $(ALL_HPP)

fmt: format clang-format

docs:
	@echo "Updating test counts in docs..."
	@DRY=$$(./$(BUILD_BIN) --help 2>/dev/null | grep -c 'dry-run' || true); \
	TC=$$(grep -c 'check_contains' tests/test_dry_run.sh 2>/dev/null || echo 0); \
	echo "  dry-run checks: $$TC"

check: $(BUILD_BIN)
	./$(BUILD_BIN) --check

ci: $(BUILD_BIN)
	./$(BUILD_BIN) --ci

once: $(BUILD_BIN)
	./$(BUILD_BIN) --once

help:
	@echo "Targets:"
	@echo "  all     Build easy-ffmpeg (default)"
	@echo "  clean   Remove binaries"
	@echo "  fmt     Format all source (Carbon + C++)"
	@echo "  format  Carbon source only"
	@echo "  clang-format  C++ headers only"
	@echo "  docs    Auto-update markdown"
	@echo "  check   Validation checks"
	@echo "  ci      Full CI pipeline"
	@echo "  once    Build + verify one-shot"
