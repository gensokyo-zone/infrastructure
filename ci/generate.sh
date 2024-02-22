#!/usr/bin/env bash
set -eu

for node in reisen; do
	nix eval --json "${NF_CONFIG_ROOT}#lib.generate.$node.users" | jq -M . > "$NF_CONFIG_ROOT/systems/$node/users.json"
done
