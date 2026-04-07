{
  description = "zuil";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          zig
          zls
        ];

        # Zig uses its own sysroot; Nix C flags interfere with framework linking.
        shellHook = ''
          unset NIX_CFLAGS_COMPILE
          unset NIX_LDFLAGS
        '';
      };
    };
}
