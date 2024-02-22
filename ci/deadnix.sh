#!/usr/bin/env bash
set -eu

NF_NIX_BLACKLIST_FILES=(
	$(find "${NF_NIX_BLACKLIST_DIRS[@]}" -type f)
)

exec deadnix "$@" \
	--no-lambda-arg \
	--exclude "${NF_NIX_BLACKLIST_FILES[@]}"
