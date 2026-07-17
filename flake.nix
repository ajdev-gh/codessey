{
  description = "Blog Builder";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      perSystem = { config, pkgs, system, ... }: {
        # 1. The production package used by 'nix build' and the GitHub Actions runner
        packages.default = pkgs.stdenv.mkDerivation {
          name = "hugo-site";
          src = ./.;
          nativeBuildInputs = [ pkgs.hugo pkgs.git ];
          dontConfigure = true;
          buildPhase = ''
            hugo --gc --minify
          '';
          installPhase = ''
            cp -r public $out
          '';
        };

        # 2. Your local interactive environment shell
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.hugo
            pkgs.git
          ];

          shellHook = ''
            echo "⚡ Nix-managed Hugo environment active."
            echo "🚀 Run 'hugo server' to preview your site locally."
          '';
        };
      };
    };
}
