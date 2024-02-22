#!/usr/bin/env bash
set -eu

docs_try() {
	local CMD=$1
	shift

	if type -P "$CMD" > /dev/null 2>&1; then
		exec "$CMD" "$NF_DOCS_PATH/index.html" "$@"
	fi
}

docs_try xdg-open "$@"
docs_try open "$@"
docs_try firefox "$@"
docs_try chrome "$@"
