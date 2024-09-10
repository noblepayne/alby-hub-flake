{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    supportedSystems = ["x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin"];
    pkgsBySystem = nixpkgs.lib.getAttrs supportedSystems nixpkgs.legacyPackages;
    forAllPkgs = fn: nixpkgs.lib.mapAttrs (system: pkgs: (fn pkgs)) pkgsBySystem;
    version = "1.7.3";
  in {
    formatter = forAllPkgs (pkgs: pkgs.alejandra);
    packages = forAllPkgs (pkgs: {
      albyHubSrc = pkgs.fetchFromGitHub {
        owner = "getAlby";
        repo = "hub";
        rev = "v${version}";
        hash = "sha256-r0hIwtlsn1qd7c88DIMimuqOecLocF0Y19aK3My/DxQ=";
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
