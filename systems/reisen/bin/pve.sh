#!/usr/bin/env bash
set -eu

ARG_CMD=$1
shift

case "$ARG_CMD" in
	qm|pct|pveum)
		;;
	*)
		echo unsupported pve command "$ARG_CMD" >&2
		exit 1
		;;
esac

exec "$ARG_CMD" "$@"
