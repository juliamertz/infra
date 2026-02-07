{
  kubenix,
  lib,
  ...
}: let
  modules = [
    ./cloudnative-pg
    ./cert-manager
    ./dragonfly-operator
  ];
in {
  imports = with kubenix.modules; [submodules k8s];

  submodules.imports = modules;
  submodules.instances =
    lib.genAttrs (modules |> map baseNameOf) (name: let
    in {submodule = name;});
}
