#!/usr/bin/env bash
set -eu
ARG_NODE=$1
shift
ARG_HOSTNAME=$(nf-hostname "$ARG_NODE")
NIX_SSHOPTS=$(nf-sshopts "$ARG_NODE")

exec ssh $NIX_SSHOPTS "$ARG_HOSTNAME" "$@"
