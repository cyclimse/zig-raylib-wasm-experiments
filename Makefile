EMSCRIPTEN_ROOT := $(shell echo $$EMSCRIPTEN_ROOT)
ifeq ($(EMSCRIPTEN_ROOT),)
$(error EMSCRIPTEN_ROOT is not set)
endif

all: build_release_wasm

.PHONY: build_release_wasm
build_release_wasm:
	@echo "Building release wasm..."
	@zig build --release=fast -Dtarget=wasm32-emscripten --sysroot $(EMSCRIPTEN_ROOT)
