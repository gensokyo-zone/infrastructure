#!/usr/bin/env bash
set -eu
shopt -s extglob

ARG_VMID=$1
shift

case "$ARG_VMID" in
	+([0-9]))
		;;
	*)
		echo unknown vmid "$ARG_VMID" >&2
		exit 1
		;;
esac

LXC_CONF_PATH="/etc/pve/lxc/$ARG_VMID.conf"

if [[ ! -e $LXC_CONF_PATH ]]; then
	echo missing vmid "$ARG_VMID" >&2
	exit 1
fi

ARG_VARS=("$@")

EXCLUDE_KEYS=(
	-e "^lxc\\."
)

while [[ $# -gt 0 ]]; do
	ARG_VAR="$1"
	ARG_VALUE="$2"
	shift 2
	EXCLUDE_KEYS+=(
		-e "^${ARG_VAR//./\\.}:"
	)
done
set -- "${ARG_VARS[@]}"

LXC_CONF=$(grep -v "${EXCLUDE_KEYS[@]}" "$LXC_CONF_PATH")

cat > "$LXC_CONF_PATH" <<<"$LXC_CONF"
while [[ $# -gt 0 ]]; do
	ARG_VAR="$1"
	ARG_VALUE="$2"
	shift 2
	echo "$ARG_VAR: $ARG_VALUE"
done >> "$LXC_CONF_PATH"
