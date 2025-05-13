let 
  nixosConfigs = {};
  terraformOutputs = {};
in
{
  meta = {
    nixpkgs = <nixpkgs>;
  };

  # TODO: Problematic?
  # defaults = { pkgs, ... }: {
  # };

  host-a = {
    name,
    nodes,
    ...
  }: {
    import = [
      "${nixosConfigs}/host-a.nix"
      "${terraformOutputs}/host-a.nix"
    ];
  };

  {% for (host, config_path) in hosts %}
    {{ host.hostname }} = {
      name,
      nodes,
      ...
    }: {
      import = [
        "{{ host.config }}"
      ];

      deployment = {
        targetHost = "{{ host.ip }}";
        targetUser = "root";
        targetPort = 22;
      };
    };
  {% endfor %}
}
