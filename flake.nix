{
  description = "My Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";

    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:MarceColl/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { nixpkgs, home-manager, zen-browser, nixpkgs-unstable, ... }@inputs:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;

      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          allowBroken = true;
        };
      };

      unstablePkgs = import nixpkgs-unstable {
        inherit system;
        config = {
          allowUnfree = true;
          allowBroken = true;
        };
      };
    in {
      homeConfigurations.myprofile = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {
          inherit inputs unstablePkgs;
        };

        modules = [
          ({ pkgs, inputs, unstablePkgs, ... }: {
            home.packages = with pkgs; [
              inputs.zen-browser.packages.${system}.default

            ];

            nixpkgs.config = {
              allowUnfree = true;
              allowBroken = true;
            };
          })

          ./home.nix
        ];
      };
    };
}
