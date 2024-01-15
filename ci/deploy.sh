#!/usr/bin/env bash
set -eu

NF_CONFIG_ROOT=${NF_CONFIG_ROOT-.}

NF_HOST=${NF_HOST-tewi}
NIXOS_TOPLEVEL=network.nodes.$NF_HOST.system.build.toplevel
NF_ADDR=${NF_ADDR-${NF_HOST}.local}

if [[ $NF_ADDR = tewi.local ]]; then
	# work around homekit namespace clash
	NF_ADDR=tewi.local.gensokyo.zone
fi

if [[ $# -eq 0 ]]; then
	set -- ""
fi

if [[ $1 = tarball ]]; then
	shift
	set -- build "$@"
	NIXOS_TOPLEVEL=network.nodes.$NF_HOST.system.build.tarball
fi

if [[ $1 = build ]]; then
	shift
	exec nix build --no-link --print-out-paths \
		$NF_CONFIG_ROOT\#$NIXOS_TOPLEVEL \
		"$@"
elif [[ $1 = switch ]] || [[ $1 = boot ]] || [[ $1 = test ]] || [[ $1 = dry-* ]]; then
	METHOD=$1
	shift
	exec nixos-rebuild $METHOD \
		--flake $NF_CONFIG_ROOT\#$NF_HOST \
		--no-build-nix \
		--target-host $NF_ADDR --use-remote-sudo \
		"$@"
elif [[ $1 = check ]]; then
	EXIT_CODE=0
	DEFAULT=$(nix eval --raw -f $NF_CONFIG_ROOT $NIXOS_TOPLEVEL)
	FLAKE=$(nix eval --raw $NF_CONFIG_ROOT\#$NIXOS_TOPLEVEL)
	if [[ $DEFAULT != $FLAKE ]]; then
		echo default.nix: $DEFAULT
		echo flake.nix: $FLAKE
		EXIT_CODE=1
	else
		echo untrusted ok: $FLAKE
	fi
	exit $EXIT_CODE
elif [[ $1 = ssh ]]; then
	shift
	exec ssh $NIX_SSHOPTS $NF_ADDR "$@"
elif [[ $1 = sops-keyscan ]]; then
	shift
	ssh-keyscan $NIX_SSHOPTS $NF_ADDR | nix run nixpkgs#ssh-to-age
else
	echo unknown cmd $1 >&2
	exit 1
fi
