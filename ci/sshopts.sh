#!/usr/bin/env bash
set -eu
ARG_HOSTNAME=$1
ARG_NODE=${ARG_HOSTNAME%%.*}

if DEPLOY_SSHOPTS=$(nix eval --json "${NF_CONFIG_ROOT}#deploy.nodes.$ARG_HOSTNAME.sshOpts" 2>/dev/null); then
	SSHOPTS=($(jq -r '.[]' <<<"$DEPLOY_SSHOPTS"))
	echo "${SSHOPTS[*]}"
elif [[ $ARG_NODE = reisen ]]; then
	SSHOPTS=()
else
	SSHOPTS=(${NIX_SSHOPTS--p62954})
fi

if [[ $ARG_NODE = ct || $ARG_NODE = reisen-ct ]]; then
	SSHOPTS+=(-oUpdateHostKeys=no -oStrictHostKeyChecking=off)
else
	SSHOPTS+=(-oHostKeyAlias=$ARG_NODE.gensokyo.zone)
fi

echo "${SSHOPTS[*]}"
