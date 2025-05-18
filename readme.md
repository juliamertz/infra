# Prerequisites

This repo uses [direnv]() extensively to make things work, make sure you have it installed
Deployment secrets are handled with [sops]() make sure this is set up

# Deployment

Make sure you're set up to decrypt the secrets then apply with tofu

```sh
tofu apply -auto-approve
```

This will provision the servers with their nixos configs and set up DNS with cloudflare.

# TODO

- [ ] Refactor terraform outputs and deserialize as nix structure
- [ ] key won't match when server is destroyed and created, we have to sed out the lines in `~/.ssh/known_hosts`
