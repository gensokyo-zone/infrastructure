#!/usr/bin/env bash
set -eu
NF_SETUP_NODE_HOST=${NF_SETUP_NODE_HOST-$NF_SETUP_NODE_NAME}
NF_SETUP_INPUTS_NAME="NF_SETUP_INPUTS_${NF_SETUP_NODE_NAME}[@]"

exec ssh root@$NF_SETUP_NODE_HOST env \
	"${!NF_SETUP_INPUTS_NAME}" \
	"bash -c \"eval \\\"\\\$(base64 -d <<<\\\$INPUT_INFRA_SETUP)\\\"\""
