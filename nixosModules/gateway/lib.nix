{...}: {
  reverseProxy = address: ''
    reverse_proxy ${address}
  '';

  redirect = address: "redir ${address}";

  basicAuth = password: config: ''
    basicauth {
        username ${password}
    }

    ${config}
  '';
}
