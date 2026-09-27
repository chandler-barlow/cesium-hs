{

  inputs = {
    miso.url = "git+ssh://git@github.com/dmjio/miso.git";
  };

  outputs = inputs:
    inputs.miso.inputs.flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = inputs.miso.inputs.nixpkgs.legacyPackages.${system};
      in {
        # zlib layered on top for the native adsb-proxy executable
        # (http-client/warp's dependency chain needs libz) - the wasm
        # shell doesn't need this, so it's left untouched below.
        devShell = pkgs.mkShell {
          inputsFrom = [ inputs.miso.outputs.devShells.${system}.default ];
          buildInputs = [ pkgs.zlib ];
        };
        devShells.wasm = inputs.miso.outputs.devShells.${system}.wasm;
        devShells.ghcjs = inputs.miso.outputs.devShells.${system}.ghcjs;
      });

}
