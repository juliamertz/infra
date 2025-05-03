#!/usr/bin/env sh

export PROVIDER=hetznercloud
export NIX_CHANNEL="${nixos_channel}"

export BIN="$(mktemp -d)"
export PATH="$PATH:$BIN"

curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect > "$BIN/nixos-infect"
chmod +x "$BIN/nixos-infect"

nixos-infect
