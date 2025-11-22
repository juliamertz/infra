{
  buildGoModule,
  fetchFromGitHub,
  ...
}:
buildGoModule {
  pname = "hcloud-upload-image";
  version = "0.1.2";
  src = fetchFromGitHub {
    owner = "apricote";
    repo = "hcloud-upload-image";
    rev = "a9b16cf07cdeb973437a73206788273d0f766273";
    hash = "sha256-J+op+zBwqwFNQmTqXqnABqoDuFBLQuSRE3O/GFoRgIk=";
  };

  vendorHash = "sha256-GFJvj69L8aP80WBuPX46NIpDAsBY2axAbp941gqvLtA=";
  proxyVendor = true;

  meta.mainProgram = "hcloud-upload-image";

  GO_TEST = "none";
}
