{
  description = "minimal rust nix project";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = { nixpkgs.follows = "nixpkgs"; };
    };

    crane = { url = "github:ipetkov/crane"; };
  };
  outputs = { nixpkgs, utils, rust-overlay, crane, ... }:
    utils.lib.eachDefaultSystem (system:
      let
        ## no cross compiling because of tutorials.
        overlays = [ (import rust-overlay) ];

        ## just import the current system deps
        pkgs = import nixpkgs { inherit system overlays; };

        inherit (pkgs) lib;

        rustToolchain = pkgs.pkgsBuildHost.rust-bin.fromRustupToolchainFile
          ./rust-toolchain.toml;

        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;

        ## have to filter out the quentions.json testing database
        questionJson = path: _type: builtins.match ".*json$" path != null;
        questionOrCargo = path: type:
          (questionJson path type) || (craneLib.filterCargoSources path type);

        src = lib.cleanSourceWith {
          src = ./.;
          filter = questionOrCargo;
          name = "source";
        };

        ## apple silicone cpu packages for building
        nativeBuildInputs = [ rustToolchain ]
          ++ lib.optionals pkgs.stdenv.isDarwin [
            pkgs.darwin.apple_sdk.frameworks.Foundation
            pkgs.darwin.apple_sdk.frameworks.SystemConfiguration
            pkgs.darwin.apple_sdk.frameworks.CoreServices
            pkgs.darwin.apple_sdk.frameworks.CoreFoundation
          ];

        buildInputs = with pkgs;
          [ podman podman-compose ]
          ++ lib.optionals pkgs.stdenv.isDarwin [ pkgs.libiconv ];

        commonArgs = {
          inherit src buildInputs nativeBuildInputs;
          strictDeps = true;
        };
        cargoArtifacts = craneLib.buildDepsOnly commonArgs;

        individualCrateArgs = commonArgs // {
          inherit cargoArtifacts;
          inherit (craneLib.crateNameFromCargoToml { inherit src; }) version;
          doCheck = false;
        };

        ## package handle-errors lib
        handle-errors = craneLib.buildPackage (individualCrateArgs // {
          pname = "handle-errors";
          cargoExtraArgs = "-p handle-errors";
          src = ./handle-errors;
        });

        bin = craneLib.buildPackage (commonArgs // { inherit cargoArtifacts; });

      in with pkgs; {
        packages = {
          inherit bin handle-errors;
          default = bin;
        };

        devShells.default = craneLib.devShell {
          inputsFrom = [ bin ];
          packages = [ cargo-watch sqlx-cli ];
        };
      });
}
