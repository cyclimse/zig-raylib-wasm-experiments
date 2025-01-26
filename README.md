# Zig + RayLib + Wasm Experiments

A collection of small experiments using Zig, RayLib and WebAssembly.

## Exploring

You can play with the experiments on the GitHub Pages site [here](https://cyclimse.github.io/zig-raylib-wasm-experiments/).

## Running

This is setup to run on NixOS, but hopefully it should work on other systems too with some modifications.

Make sure you have Zig installed!

In my case, `zig` is installed and managed separately using [zigup](https://github.com/marler8997/zigup).

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
zig build run_<program> --release=safe -Dtarget=wasm32-emscripten --sysroot $EMSCRIPTEN_ROOT
```

This will directly open the program in your browser.

## References

- [RayLib](https://www.raylib.com/)
- [raylib-zig](https://github.com/Not-Nik/raylib-zig)
