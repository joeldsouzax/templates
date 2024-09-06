{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = { nixpkgs.follows = "nixpkgs"; };
    };
    crane = {
      url = "github:ipetkov/crane";
      inputs = { nixpkgs.follows = "nixpkgs"; };
    };

    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
  };
  outputs = { self, nixpkgs, flake-utils, rust-overlay, crane, advisory-db }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };
        rustToolchain = pkgs.pkgsBuildHost.rust-bin.fromRustupToolchainFile
          ./rust-toolchain.toml;

        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;
        src = craneLib.cleanCargoSource ./.;

        # native builds needed for building
        nativeBuildInputs = with pkgs; [ rustToolchain ];

        # utils needed for running of the application.
        buildInputs = with pkgs; [ ];
        commonArgs = {
          inherit src buildInputs nativeBuildInputs;
          strictDeps = true;
        };
        cargoArtifacts = craneLib.buildDepsOnly commonArgs;

        bin = craneLib.buildPackage (commonArgs // {
          inherit cargoArtifacts;
        }); # actual app building here :D

        coverage =
          craneLib.cargoTarpaulin (commonArgs // { inherit cargoArtifacts; });

        clippy = craneLib.cargoClippy (commonArgs // {
          inherit cargoArtifacts;
          cargoClippyExtraArgs = "--all-targets -- --deny warnings";
        });

        docs = craneLib.cargoDoc (commonArgs // { inherit cargoArtifacts; });

        fmt = craneLib.cargoFmt { inherit src; };

        audit = craneLib.cargoAudit { inherit src advisory-db; };

        deny = craneLib.cargoDeny { inherit src; };

        dockerImage = pkgs.dockerTools.streamLayeredImage {
          name = "my-app"; # FIXME: change the name
          tag = "latest";
          contents = [ bin ];
          config = { Cmd = [ "${bin}/bin/my-app" ]; }; # FIXME: change the name
        };

      in with pkgs; {

        checks = { inherit clippy coverage docs fmt audit deny; };
        packages = {
          inherit bin dockerImage;
          default = bin;
        };

        devShells.default = craneLib.devShell {
          inputsFrom = [ bin ];
          packages = [ cargo-audit cargo-watch dive docker flyctl just ];
        };
      });
}
