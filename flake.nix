{
  description = "NixOS Version Control Flake";

  inputs = {
    # Nix Package Repositories
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixpkgs-old.url = "github:nixos/nixpkgs?ref=nixos-24.11";
  };

  outputs = { self, nixpkgs, nixpkgs-old, ... }@inputs:
  let
    system = "x86_64-linux";
    pkgs = "nixpkgs.legacyPackages.${system}";
    pkgs-old = "nixpkgs-old.legacyPackages.${system}";
  in {
    nixosConfigurations.nixos-desktop = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs system; };
      modules = [ 
        ./configuration.nix 
      ];
    };
  };
}
