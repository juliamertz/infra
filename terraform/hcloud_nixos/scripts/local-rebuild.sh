#!/usr/bin/env sh

mv -v ~/.ssh/known_hosts ~/.ssh/known_hosts.bak
trap 'mv -v ~/.ssh/known_hosts.bak ~/.ssh/known_hosts' EXIT

ssh-keyscan -H ::1 >> ~/.ssh/known_hosts
ssh-keyscan -H localhost >> ~/.ssh/known_hosts
ssh-keyscan -H "$SSH_ADDRESS" >> ~/.ssh/known_hosts

nixos-rebuild switch --target-host "$SSH_USER@$SSH_ADDRESS" --build-host localhost --flake "$FLAKE"
