{
  kubenix,
  pkgs,
  lib,
  ...
}: let
  fromYAML = yaml: let
    path = pkgs.writeText "yaml" yaml;
    json = pkgs.runCommand "json-output" {} ''
      cat ${path} | ${lib.getExe pkgs.yq} -s >> $out
    '';
  in
    builtins.readFile json |> builtins.fromJSON;

  loadYAML = path: builtins.readFile path |> fromYAML;

  fetchYAML = {
    url,
    sha256 ? "",
  }:
    pkgs.fetchurl {inherit url sha256;}
    |> builtins.readFile
    |> fromYAML;

  isCrd = resource: resource.kind == "CustomResourceDefinition";

  configMapValueRef = name: {
    type = "ValueRef";
    valueRef = {
      group = "";
      kind = "ConfigMap";
      inherit name;
    };
  };

  util = {inherit fromYAML loadYAML fetchYAML isCrd configMapValueRef;};

  evalKubenix = imports: let
    inherit (pkgs.stdenv.hostPlatform) system;
    output = kubenix.evalModules.${system} {
      module = {...}: {inherit imports;};
      specialArgs = {
        inherit util;
        crds = import ./types;
      };
    };
  in
    output.config.kubernetes.result
    // {
      passthru = {
        module = output;
      };
    };
in
  util // {inherit evalKubenix;}
