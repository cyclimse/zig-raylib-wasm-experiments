# Zig + RayLib + Wasm Experiments

A collection of small experiments using Zig, RayLib and WebAssembly.

## Running

This is setup to run on NixOS, but hopefully it should work on other systems too.

Zig is installed and managed separately using [zigup](https://github.com/marler8997/zigup).

```console
zigup install 0.13.0
```

Then, you can run the project using the following commands:

```console
nix-shell # or direnv allow if you have direnv setup
zig build run_<program>

# For example:
zig build run_maze2d
```

### Running on the Web

You can also run the programs on the web using WebAssembly.

```console
zig build run_<program> -Dtarget=wasm32-emscripten --sysroot $EMSCRIPTEN_ROOT
```

This will directly open the program in your browser.
