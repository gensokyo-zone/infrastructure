#!/usr/bin/env bash
set -eu
SETUP_HOSTNAME=''${1-reisen}

exec ssh root@$SETUP_HOSTNAME env \
	"${NF_SETUP_INPUTS[@]}" \
	"bash -c \"eval \\\"\\\$(base64 -d <<<\\\$INPUT_INFRA_SETUP)\\\"\""
