{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    supportedSystems = ["x86_64-linux" "aarch64-linux"];
    pkgsBySystem = nixpkgs.lib.getAttrs supportedSystems nixpkgs.legacyPackages;
    forAllPkgs = fn: nixpkgs.lib.mapAttrs (system: pkgs: (fn pkgs)) pkgsBySystem;
    version = "1.12.0";
  in {
    formatter = forAllPkgs (pkgs: pkgs.alejandra);
    packages = forAllPkgs (pkgs: {
      albyHubSrc = pkgs.fetchFromGitHub {
        owner = "getAlby";
        repo = "hub";
        rev = "v${version}";
        hash = "sha256-m3ImIz9qQVFZAjZPuVFkGANhWFIJp0uGDknfhouHHBo=";
      };
      albyHubUI = pkgs.callPackage ./frontend.nix {
        inherit version;
        inherit (self.packages.${pkgs.system}) albyHubSrc;
      };
      albyHub = pkgs.callPackage ./alby-hub.nix {
        inherit version;
        inherit (self.packages.${pkgs.system}) albyHubSrc;
      };
      wails = pkgs.callPackage ./wails.nix {
        inherit version;
        inherit (self.packages.${pkgs.system}) albyHubSrc;
      };
      default = self.packages.${pkgs.system}.albyHub;
    });
  };
}
