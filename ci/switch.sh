#!/usr/bin/env bash
set -eu
ARG_NODE=$1
shift
ARG_HOSTNAME=$(nf-hostname "$ARG_NODE")
NIX_SSHOPTS=$(nf-sshopts "$ARG_NODE")

if [[ $# -gt 0 ]] && [[ ${1-} != -* ]]; then
	ARG_METHOD=$1
	shift
else
	ARG_METHOD=switch
fi

if [[ $ARG_HOSTNAME != root@ ]]; then
	set -- --use-remote-sudo "$@"
fi

exec nixos-rebuild "$ARG_METHOD" \
	--flake "${NF_CONFIG_ROOT}#${ARG_NODE}" \
	--no-build-nix \
	--target-host "$ARG_HOSTNAME" \
	"$@"
