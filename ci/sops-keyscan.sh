#!/usr/bin/env bash
set -eu
ARG_NODE=$1
shift
ARG_HOSTNAME=$(nf-hostname "$ARG_NODE")

ssh-keyscan ''${NIX_SSHOPTS--p62954} "''${ARG_HOSTNAME#*@}" "$@" | ssh-to-age
