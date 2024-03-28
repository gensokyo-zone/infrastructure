#!/usr/bin/env bash
set -eu

for node in reisen; do
	nix eval --json "${NF_CONFIG_ROOT}#lib.generate.$node.users" | jq -M . > "$NF_CONFIG_ROOT/systems/$node/users.json"
	nix eval --json "${NF_CONFIG_ROOT}#lib.generate.$node.systems" | jq -M . > "$NF_CONFIG_ROOT/systems/$node/systems.json"
done
nix eval --json "${NF_CONFIG_ROOT}#lib.generate.systems" | jq -M . > "$NF_CONFIG_ROOT/ci/systems.json"

for ciconfig in "${NF_CONFIG_FILES[@]}"; do
	echo "processing ${ciconfig}..." >&2
	nix run --argstr config "$NF_CONFIG_ROOT/ci/$ciconfig" -f "$NF_INPUT_CI" run.gh-actions-generate
done
