{
  description = "NixOS Version Control Flake";

  inputs = {
    ### Flakes
    # Nix Package Repositories
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable"; # Current Stable
    nixpkgs-old.url = "github:nixos/nixpkgs?ref=nixos-24.11"; # Unstable

    # Home manager
    home-manager = {
      url = "github:nix-community/home-manager?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-old,
    home-manager,
    ...
  } @ inputs: let
    system = "x86_64-linux";
    pkgs = "nixpkgs.legacyPackages.${system}";
    pkgs-old = "nixpkgs-old.legacyPackages.${system}";
  in {
    nixosConfigurations.nixos-desktop = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs system;};
      modules = [
        ./configuration.nix
        ./systemd.nix

        # Home Manager Module
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.john = import ./home.nix;
          home-manager.extraSpecialArgs = {inherit inputs;};
          home-manager.backupFileExtension = "bak";
        }
      ];
    };
  };
}
