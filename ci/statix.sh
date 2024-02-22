#!/usr/bin/env bash
set -eu
if [[ $# -eq 0 ]]; then
	set -- check
fi

if [[ ${1-} = check ]]; then
	shift
	set -- check --config "$NF_CONFIG_ROOT/ci/statix.toml" "$@"
fi

exec statix "$@"
