#!/usr/bin/env bash
set -eu
if [[ $# -gt 0 ]]; then
	ARG_NODE=$1
	shift
else
	ARG_NODE=ct
fi

ARG_CONFIG_PATH=nixosConfigurations.$ARG_NODE.config
RESULT=$(nix build --no-link --print-out-paths \
	"${NF_CONFIG_ROOT}#$ARG_CONFIG_PATH.system.build.tarball" \
	--show-trace "$@")

if [[ $ARG_NODE = ct ]]; then
	DATESTAMP=$(nix eval --raw "${NF_CONFIG_ROOT}#lib.inputs.nixpkgs.sourceInfo.lastModifiedDate")
	DATENAME=${DATESTAMP:0:4}${DATESTAMP:4:2}${DATESTAMP:6:2}
	SYSARCH=$(nix eval --raw "${NF_CONFIG_ROOT}#$ARG_CONFIG_PATH.nixpkgs.system")
	TAREXT=$(nix eval --raw "${NF_CONFIG_ROOT}#$ARG_CONFIG_PATH.system.build.tarball.extension")
	TARNAME=nixos-system-$SYSARCH.tar$TAREXT
	OUTNAME="ct-$DATENAME-$TARNAME"
	ln -sf "$RESULT/tarball/$TARNAME" "$OUTNAME"
	echo $OUTNAME
	ls -l $OUTNAME
else
	echo $RESULT
fi
