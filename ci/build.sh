#!/usr/bin/env bash
set -eu
ARG_NODE=$1
shift

exec nix build --no-link --print-out-paths \
	"${NF_CONFIG_ROOT}#nixosConfigurations.$ARG_NODE.config.system.build.toplevel" \
	--show-trace "$@"
