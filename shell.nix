{ pkgs ? import <nixpkgs> { }, unstable ? import <nixos-unstable> { } }:

pkgs.mkShell {
  nativeBuildInputs = with pkgs.buildPackages; [
    unstable.zls

    # Raylib dependencies
    libGL
    xorg.libXcursor
    xorg.libXrandr
    xorg.libXinerama
    xorg.libXi
    xorg.libX11.dev
  ];

  EM_CONFIG = pkgs.writeText ".emscripten" ''
    EMSCRIPTEN_ROOT = '${pkgs.emscripten}/share/emscripten'
    LLVM_ROOT = '${pkgs.emscripten.llvmEnv}/bin'
    BINARYEN_ROOT = '${pkgs.binaryen}'
    NODE_JS = '${pkgs.nodejs-18_x}/bin/node'
    NODE_PATH = '${pkgs.emscripten.nodeModules}'
    CACHE = '${toString ./.cache}'
  '';

  buildInputs = [
    pkgs.python3
    pkgs.nodejs-18_x
    pkgs.emscripten
  ];

  EMSCRIPTEN_ROOT = "${pkgs.emscripten}/share/emscripten";
}
