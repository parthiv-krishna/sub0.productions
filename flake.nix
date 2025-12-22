{
  description = "Website for Sub0 Productions";

  inputs = {
    flake-utils = {
      url = "github:numtide/flake-utils";
    };
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-unstable";
    };
    papaya = {
      url = "github:justint/papaya";
      flake = false;
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (nixpkgs) lib;

        treefmtEval = inputs.treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";
          programs.mdformat.enable = true;
          programs.nixfmt.enable = true;
          programs.taplo.enable = true;
        };
      in
      {
        formatter = treefmtEval.config.build.wrapper;

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            treefmtEval.config.build.wrapper
            wrangler
            zola
          ];
        };

        # delete static/banner.jpg so it can be overwritten by custom image
        packages.papaya-theme = pkgs.stdenv.mkDerivation {
          name = "papaya-theme";
          src = inputs.papaya;

          installPhase = ''
            mkdir -p $out
            cp -r . $out/
            rm -f $out/static/banner.jpg
          '';
        };

        # development server
        apps.default =
          let
            name = "sub0-productions-site-dev";
          in
          {
            type = "app";
            program = lib.getExe (
              pkgs.writeShellApplication {
                inherit name;
                runtimeInputs = with pkgs; [
                  zola
                ];
                text = ''
                  # create writable local copy of papaya theme
                  rm -rf themes/papaya
                  mkdir -p themes
                  cp -r ${self.packages.${system}.papaya-theme} themes/papaya
                  chmod -R +w themes
                  zola serve
                '';
              }
            );
          };

        # production site
        packages.default = pkgs.stdenv.mkDerivation {
          name = "sub0-productions-site";
          src = ./.;

          buildInputs = with pkgs; [
            zola
          ];

          buildPhase = ''
            mkdir -p themes
            ln -s ${self.packages.${system}.papaya-theme} themes/papaya
            export ZOLA_ENV=prod
            zola build
          '';

          installPhase = ''
            cp -r public $out
          '';
        };

        # deploy production site
        apps.deploy =
          let
            name = "sub0-productions-site-deploy";
            site = self.packages.${system}.default;
          in
          {
            type = "app";
            program = lib.getExe (
              pkgs.writeShellApplication {
                inherit name;
                runtimeInputs = with pkgs; [
                  wrangler
                ];
                text = ''
                  if [ -z "''${CLOUDFLARE_PROJECT_NAME:-}" ]; then
                    echo "Error: CLOUDFLARE_PROJECT_NAME environment variable is not set"
                    exit 1
                  fi
                  if [ -z "''${CLOUDFLARE_ACCOUNT_ID:-}" ]; then
                    echo "Error: CLOUDFLARE_ACCOUNT_ID environment variable is not set"
                    exit 1
                  fi
                  if [ -z "''${CLOUDFLARE_API_TOKEN:-}" ]; then
                    echo "Error: CLOUDFLARE_API_TOKEN environment variable is not set"
                    exit 1
                  fi

                  wrangler pages deploy ${site} \
                    --project-name="$CLOUDFLARE_PROJECT_NAME" \
                    --commit-dirty=true
                '';
              }
            );
          };
      }
    );
}
