#!/usr/bin/env bash
set -eu
if [[ $# -gt 0 ]]; then
	ARG_NODE=$1
	shift
else
	ARG_NODE=ct-reisen
fi

ARG_CONFIG_PATH=nixosConfigurations.$ARG_NODE.config
RESULT=$(nix build --no-link --print-out-paths \
	"${NF_CONFIG_ROOT}#$ARG_CONFIG_PATH.system.build.tarball" \
	--show-trace "$@")

IMAGEPATH="$(nix eval --raw "${NF_CONFIG_ROOT}#$ARG_CONFIG_PATH.image.filePath")"
if [[ $ARG_NODE = ct-* ]]; then
	#DATESTAMP=$(nix eval --raw "${NF_CONFIG_ROOT}#lib.inputs.nixpkgs.sourceInfo.lastModifiedDate")
	#DATENAME=${DATESTAMP:0:4}${DATESTAMP:4:2}${DATESTAMP:6:2}
	#IMAGEEXT="$(nix eval --raw "${NF_CONFIG_ROOT}#$ARG_CONFIG_PATH.image.extension")"
	#OUTNAME="$ARG_NODE-$DATENAME-nixos-image.${IMAGEEXT}"
	OUTNAME=$(basename "$IMAGEPATH")
	ln -sf "$RESULT/$IMAGEPATH" "./$OUTNAME"
	echo $OUTNAME
	ls -l $OUTNAME >&2
else
	echo "$RESULT/$IMAGEPATH"
fi
