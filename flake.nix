{

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    press = {
      url = "github:RossSmyth/press";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    inputs:
    inputs.parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;
      imports = [ inputs.pre-commit-hooks.flakeModule ];
      perSystem =
        {
          system,
          config,
          pkgs,
          lib,
          ...
        }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [ (import inputs.press) ];
          };

          pre-commit = {
            check.enable = true;
            settings.hooks = {
              nixfmt-rfc-style = {
                enable = true;
                stages = [ "pre-commit" ];
              };
              typstyle = {
                enable = false;
                stages = [ "pre-commit" ];
              };
            };
          };

          packages = {

            fontawesome = (
              pkgs.runCommandNoCC "fontawesome" { } ''
                mkdir -p $out/share/fonts/fontawesome
                cp ${pkgs.python3Packages.fontawesomefree}/lib/python3*/site-packages/fontawesomefree/static/fontawesomefree/otfs/*.otf $out/share/fonts/fontawesome/
              ''
            );

            grotesk-cv = pkgs.buildTypstPackage (finalAttrs: {
              pname = "grotesk-cv";
              version = "1.0.4";
              src =
                with lib.fileset;
                toSource {
                  root = ./.;
                  fileset = unions [
                    ./typst.toml
                    ./src/lib.typ
                    ./src/template/info.toml

                  ];
                };
              typstDeps = with pkgs.typstPackages; [
                fontawesome
                octique
                use-tabler-icons
                use-academicons
              ];
            });

            default = pkgs.buildTypstDocument {
              # [Optional] The name of the derivation
              # Default: ${pname}-${version}
              name = "template";
              # Source directory to copy to the store.
              src = ./src/template;
              # [Optional] The entry-point to the document, default is "main.typ"
              # This is relative to the directory input above.
              # Default: "main.typ"
              file = "cv.typ";
              # [Optional] Typst universe package selection
              #
              # Pass in a function that accept an attrset of Typst pacakges,
              # and returns a list of packages.
              #
              # The input parameter is from the pkgs.typstPackages attributes
              # in nixpkgs. See this section of the nixpkgs reference for patching
              # and overriding
              # https://nixos.org/manual/nixpkgs/unstable/#typst
              #
              # Default: (_: [])
              typstEnv = (p: with p; [ config.packages.grotesk-cv ]);
              # [Optional] Any non-universe packages. The attribute key is the namespace.
              # The package must have a typst.toml file in its root.
              # Default: {}
              extraPackages = {
                #preview = [ ./. ];
              };
              # [Optional] The format to output
              # Default: "pdf"
              # Can be either "pdf" or "html"
              format = "pdf";
              # [Optional] The fonts to include in the build environment
              # Note that they must follow the standard of nixpkgs placing fonts
              # in $out/share/fonts/. Look at Inconsolta or Fira Code for reference.
              # Default: []
              fonts = [
                pkgs.hanken-grotesk
                config.packages.fontawesome
              ];
              # [Optional] Whether to have a verbose Typst compilation session
              # Default: false
              verbose = false;
            };
          };

          devShells.default = pkgs.mkShellNoCC {
            name = "cv";
            inputsFrom = [ config.packages.default ];
            packages = with pkgs; [
              # Typst
              typst
              typstyle
              tinymist

              # Utils
              typos
              sd
            ];

            TYPST_FONT_PATHS = pkgs.symlinkJoin {
              name = "typst-fonts";
              paths = with pkgs; [
                hanken-grotesk
                config.packages.fontawesome
              ];
            };

            shellHook = ''
              ${config.pre-commit.installationScript}
            '';
          };
        };
    };
}
