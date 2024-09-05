{
  description = "minimal rust nix project";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = { nixpkgs.follows = "nixpkgs"; };
    };
  };
  outputs = { nixpkgs, utils, rust-overlay, ... }:
    utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };

        rustToolchain = pkgs.pkgsBuildHost.rust-bin.fromRustupToolchainFile
          ./rust-toolchain.toml;

        nativeBuildInputs = with pkgs; [ rustToolchain ];

        commonBuildInputs = with pkgs; [ cargo-watch ];

        macOSBuildInputs = with pkgs; [
          darwin.apple_sdk.frameworks.SystemConfiguration
          darwin.apple_sdk.frameworks.CoreServices
          darwin.apple_sdk.frameworks.CoreFoundation
        ];

        allBuildInputs =
          if system == "aarch64-darwin" || system == "x86_64-darwin" then
            commonBuildInputs ++ macOSBuildInputs
          else
            commonBuildInputs;
      in with pkgs; {
        devShells.default = mkShell {
          inherit nativeBuildInputs;
          buildInputs = allBuildInputs;
          shellHook = ''
            echo "minimal rust project"
            echo "creating cargo project"
            if [ ! -f Cargo.toml ]; then
                cargo init
            fi
          '';
        };
      });
}
