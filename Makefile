EMSCRIPTEN_ROOT := $(shell echo $$EMSCRIPTEN_ROOT)
ifeq ($(EMSCRIPTEN_ROOT),)
$(error EMSCRIPTEN_ROOT is not set)
endif

.PHONY: build
build:
	@echo "Building..."
	@zig build -Dtarget=wasm32-emscripten --sysroot $(EMSCRIPTEN_ROOT)
