{
  # Self-contained flake for the `keyway` chart render-test + lint runner, so it
  # can be consumed standalone
  # (github:akeylesslabs/helm-charts?dir=tools/keyway&ref=<branch>) without the
  # repo needing a root flake. Go deps are vendored in ./vendor, so buildGoModule
  # builds offline (vendorHash = null, -mod=vendor) with just a Go toolchain.
  #
  # The apps inject a helm wrapped with the helm-unittest plugin, so
  # `nix run ./tools/keyway#keyway-ci` has everything it needs — no `helm plugin
  # install`, no shell.
  description = "keyway — akeylesslabs/helm-charts render-test + lint runner";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

  outputs = {
    self,
    nixpkgs,
  }: let
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forEach = f: nixpkgs.lib.genAttrs systems (system: f {inherit system; pkgs = import nixpkgs {inherit system;};});
  in {
    packages = forEach ({pkgs, ...}: {
      keyway = pkgs.buildGoModule {
        pname = "keyway";
        version = "0.1.0";
        src = ./.;
        vendorHash = null; # in-tree vendor/
        meta.mainProgram = "keyway";
      };
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.keyway;
    });

    apps = forEach ({pkgs, system, ...}: let
      keyway = self.packages.${system}.keyway;
      # helm wrapped with the helm-unittest plugin: `helm unittest` works out of
      # the box for the render gate.
      helm = pkgs.wrapHelm pkgs.kubernetes-helm {
        plugins = [pkgs.kubernetes-helmPlugins.helm-unittest];
      };
      mk = sub: {
        type = "app";
        program = "${pkgs.writeShellApplication {
          name = "keyway-${sub}";
          runtimeInputs = [keyway helm];
          text = ''exec keyway ${sub} "$@"'';
        }}/bin/keyway-${sub}";
      };
    in {
      keyway = {
        type = "app";
        program = "${pkgs.writeShellApplication {
          name = "keyway";
          runtimeInputs = [keyway helm];
          text = ''exec keyway "$@"'';
        }}/bin/keyway";
      };
      keyway-lint = mk "lint";
      keyway-unittest = mk "unittest";
      keyway-ci = mk "ci";
      default = self.apps.${system}.keyway;
    });
  };
}
