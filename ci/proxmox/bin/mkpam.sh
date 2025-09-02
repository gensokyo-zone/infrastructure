#!/usr/bin/env bash
set -eu

ARG_NAME=$1
ARG_UID=$2
shift 2

if [[ $ARG_UID != 8??? ]]; then
	echo "uid $ARG_UID out of range" >&2
	exit 1
fi

id_exists() {
	ARG_FILE=$1
	if grep -q "^${ARG_NAME}:x:" "${ARG_FILE}"; then
		if ! grep -q "^${ARG_NAME}:x:${ARG_UID}:" "${ARG_FILE}"; then
			echo "${ARG_NAME} already exists but with unexpected id" >&2
			exit 1
		fi
		return 0
	else
		return 1
	fi
}

if ! id_exists /etc/group; then
	echo "creating group $ARG_NAME=$ARG_UID..." >&2
	groupadd \
		-g "$ARG_UID" \
		"$ARG_NAME"
fi

if ! id_exists /etc/passwd; then
	echo "creating user $ARG_NAME=$ARG_UID..." >&2
	useradd -r \
		-M -d /nonexistent -s /usr/sbin/nologin \
		-N -g "$ARG_UID" \
		-u "$ARG_UID" \
		"$ARG_NAME"
fi
