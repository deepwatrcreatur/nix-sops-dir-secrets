{
  description = "Auto-wire sops-nix secrets from a directory by filename convention";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
    in
    {
      lib = import ./lib.nix { inherit lib; };

      nixosModules = {
        default = import ./modules/nixos.nix { inherit (self) lib; };
        sops-dir-secrets = import ./modules/nixos.nix { inherit (self) lib; };
      };

      homeManagerModules = {
        default = import ./modules/home-manager.nix { inherit (self) lib; };
        sops-dir-secrets = import ./modules/home-manager.nix { inherit (self) lib; };
      };
    };
}
