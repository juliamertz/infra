{lib, ...}: {
  reverseProxy = {
    host,
    port ? null,
    protocol ? "http",
    blockedRoutes ? [],
    extraConfig ? "",
  }: ''
    ${map (route: ''respond ${route} "Unauthorized" 401'') blockedRoutes |> lib.concatStringsSep "\n"}
    ${extraConfig}
    reverse_proxy ${protocol}://${host}${lib.optionalString (port != null) ":${toString port}"}
  '';

  redirect = address: "redir ${address}";

  basicAuth = password: config: ''
    basicauth {
        username ${password}
    }

    ${config}
  '';
}
