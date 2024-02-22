#!/usr/bin/env bash
set -eu

exec nf-alejandra "${NF_NIX_WHITELIST_FILES[@]}" "$@"
