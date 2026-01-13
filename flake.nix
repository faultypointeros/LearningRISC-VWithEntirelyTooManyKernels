{
  description = "A Nix-flake-based C/C++ development environment";

  inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0"; # stable Nixpkgs

  outputs =
    { self, ... }@inputs:

    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forEachSupportedSystem =
        f:
        inputs.nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            pkgs = import inputs.nixpkgs { inherit system; };
          }
        );
    in
    {
      devShells = forEachSupportedSystem (
        { pkgs }:
        {
          default =
            pkgs.mkShell.override
              {
              }
              {
                packages =
                  with pkgs;
                  [
                    qemu
                    llvmPackages_20.clang-unwrapped
                    llvmPackages_20.bintools-unwrapped
                    asm-lsp
                  ]
                  ++ (if stdenv.hostPlatform.system == "aarch64-darwin" then [ ] else [ gdb ]);

              };
        }
      );
    };
}
