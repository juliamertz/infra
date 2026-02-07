{
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
in {inherit fromYAML fetchYAML isCrd configMapValueRef;}
