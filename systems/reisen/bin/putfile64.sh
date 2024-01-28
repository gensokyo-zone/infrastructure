#!/usr/bin/env bash
set -eu

ARG_DEST=$1
ARG_INPUT_BASE64=$2

case "$ARG_DEST" in
	*..*)
		echo ugh >&2
		exit 1
		;;
	/etc/sysctl.d/*.conf)
		ARG_IS_SYSCTL=1
		;;
	/etc/udev/rules.d/*.rules)
		ARG_IS_UDEV=1
		;;
	*)
		echo unsupported destination >&2
		exit 1
		;;
esac

base64 -d <<<"$ARG_INPUT_BASE64" \
	> "$ARG_DEST"

if [[ -n ${ARG_IS_SYSCTL-} ]]; then
	sysctl -f "$ARG_DEST"
fi

if [[ -n ${ARG_IS_UDEV-} ]]; then
	udevadm control --reload-rules
	udevadm trigger
fi
