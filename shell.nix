{pkgs ? import <nixpkgs> {}}:
pkgs.mkShell {
  packages = with pkgs; [
    opentofu
    alejandra
    treefmt
  ];
}
