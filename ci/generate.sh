#!/usr/bin/env bash
set -eu

for node in reisen; do
	nix eval --json "${NF_CONFIG_ROOT}#lib.generate.nodes.$node.users" | jq -M . > "$NF_CONFIG_ROOT/systems/$node/users.json"
	nix eval --json "${NF_CONFIG_ROOT}#lib.generate.nodes.$node.systems" | jq -M . > "$NF_CONFIG_ROOT/systems/$node/systems.json"
	nix eval --json "${NF_CONFIG_ROOT}#lib.generate.nodes.$node.extern" | jq -M . > "$NF_CONFIG_ROOT/systems/$node/extern.json"
	nix eval --raw "${NF_CONFIG_ROOT}#lib.generate.nodes.$node.ssh.root.authorizedKeys.text" > "$NF_CONFIG_ROOT/systems/$node/root.authorized_keys"
done
nix eval --json "${NF_CONFIG_ROOT}#lib.generate.systems" | jq -M . > "$NF_CONFIG_ROOT/ci/systems.json"

for ciconfig in "${NF_CONFIG_FILES[@]}"; do
	echo "processing ${ciconfig}..." >&2
	nix run --argstr config "$NF_CONFIG_ROOT/ci/$ciconfig" -f "$NF_INPUT_CI" run.gh-actions-generate
done
