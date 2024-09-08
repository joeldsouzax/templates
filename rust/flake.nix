{
  description = "minimal rust nix project";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = { nixpkgs.follows = "nixpkgs"; };
    };

    crane = {
      url = "github:ipetkov/crane";
      inputs = { nixpkgs.follows = "nixpkgs"; };
    };
  };
  outputs = { nixpkgs, utils, rust-overlay, crane, ... }:
    utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };

        rustToolchain = pkgs.pkgsBuildHost.rust-bin.fromRustupToolchainFile
          ./rust-toolchain.toml;

        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;
        src = craneLib.cleanCargoSource ./.;

        nativeBuildInputs = with pkgs; [ rustToolchain ];

        macOSBuildInputs = with pkgs; [
          darwin.apple_sdk.frameworks.SystemConfiguration
          darwin.apple_sdk.frameworks.CoreServices
          darwin.apple_sdk.frameworks.CoreFoundation
        ];

        buildInputs = with pkgs;
          if system == "aarch64-darwin" || system == "x86_64-darwin" then
            macOSBuildInputs
          else
            [ ];

        commonArgs = {
          inherit src buildInputs nativeBuildInputs;
          strictDeps = true;
        };
        cargoArtifacts = craneLib.buildDepsOnly commonArgs;

        bin = craneLib.buildPackage (commonArgs // {
          inherit cargoArtifacts;
        }); # actual app building here :D

        # docker image
        image = pkgs.dockerTools.streamLayeredImage {
          name = "my-app";
          created = "now";
          copyToRoot = [ bin ];
          config = { Cmd = [ "${bin}/bin/my-app" ]; };
        };

      in with pkgs; {
        packages = {
          inherit bin image;
          default = bin;
        };

        devShells.default = craneLib.devShell {
          inputsFrom = [ bin ];
          packages = [ cargo-watch ];
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
