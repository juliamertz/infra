#!/usr/bin/env sh

export NIX_SSHOPTS="-o StrictHostKeyChecking=accept-new"

nixos-rebuild switch --target-host "$SSH_USER@$SSH_ADDRESS" --build-host localhost --flake "$FLAKE"
