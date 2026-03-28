{
  description = "Auto-wire sops-nix secrets from a directory by filename convention";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      flakeLib = import ./lib.nix { inherit lib; };

      libInventory =
        attrs:
        {
          children = builtins.mapAttrs (
            _: value:
            if builtins.isFunction value then
              {
                what = "library function";
              }
            else if builtins.isAttrs value then
              libInventory value
            else
              {
                what = "library value";
              }
          ) attrs;
        };

      moduleInventory =
        moduleType: output:
        {
          children = builtins.mapAttrs (
            _: module:
            {
              what = moduleType;
              evalChecks.isModule = builtins.isFunction module || builtins.isAttrs module;
            }
          ) output;
        };
    in
    {
      lib = flakeLib;

      nixosModules = {
        default = import ./modules/nixos.nix { inherit (self) lib; };
        sops-dir-secrets = import ./modules/nixos.nix { inherit (self) lib; };
      };

      homeManagerModules = {
        default = import ./modules/home-manager.nix { inherit (self) lib; };
        sops-dir-secrets = import ./modules/home-manager.nix { inherit (self) lib; };
      };

      schemas = {
        lib = {
          version = 1;
          doc = "The `lib` output exposes helper functions for generating sops-nix secret definitions from a directory.";
          inventory = libInventory;
        };

        homeManagerModules = {
          version = 1;
          doc = "The `homeManagerModules` output exposes Home Manager modules.";
          inventory = moduleInventory "Home Manager module";
        };
      };
    };
}
