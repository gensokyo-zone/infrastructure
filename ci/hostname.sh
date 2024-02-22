#!/usr/bin/env bash
set -eu

DEPLOY_USER=
if [[ $# -gt 1 ]]; then
	ARG_NODE=$1
	ARG_HOSTNAME=$2
	shift 2
else
	ARG_HOSTNAME=$1
	shift
	ARG_NODE=${ARG_HOSTNAME%%.*}
	if [[ $ARG_HOSTNAME = $ARG_NODE ]]; then
		if DEPLOY_HOSTNAME=$(nix eval --raw "${NF_CONFIG_ROOT}#deploy.nodes.$ARG_HOSTNAME.hostname" 2>/dev/null); then
			DEPLOY_USER=$(nix eval --raw "${NF_CONFIG_ROOT}#deploy.nodes.$ARG_HOSTNAME.sshUser" 2>/dev/null || true)
			ARG_HOSTNAME=$DEPLOY_HOSTNAME
			if ! ping -w2 -c1 "$DEPLOY_HOSTNAME" >/dev/null 2>&1; then
				ARG_HOSTNAME="$ARG_NODE.local"
			fi
		else
			ARG_HOSTNAME="$ARG_NODE.local"
		fi
	fi
fi

if ! ping -w2 -c1 "$ARG_HOSTNAME" >/dev/null 2>&1; then
	LOCAL_HOSTNAME=$ARG_NODE.local.gensokyo.zone
	TAIL_HOSTNAME=$ARG_NODE.tail.gensokyo.zone
	GLOBAL_HOSTNAME=$ARG_NODE.gensokyo.zone
	if ping -w2 -c1 "$LOCAL_HOSTNAME" >/dev/null 2>&1; then
		ARG_HOSTNAME=$LOCAL_HOSTNAME
	elif ping -w2 -c1 "$TAIL_HOSTNAME" >/dev/null 2>&1; then
		ARG_HOSTNAME=$TAIL_HOSTNAME
	elif ping -w2 -c1 "$GLOBAL_HOSTNAME" >/dev/null 2>&1; then
		ARG_HOSTNAME=$GLOBAL_HOSTNAME
	fi
fi

echo "${DEPLOY_USER-}${DEPLOY_USER+@}$ARG_HOSTNAME"
