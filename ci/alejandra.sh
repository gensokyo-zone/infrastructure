#!/usr/bin/env bash
set -eu

for blacklist_dir in "${NF_NIX_BLACKLIST_DIRS[@]}"; do
	set -- --exclude "$blacklist_dir" "$@"
done

exec alejandra "$@"
