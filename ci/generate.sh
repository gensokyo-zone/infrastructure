#!/usr/bin/env bash
set -eu

NF_GENERATE_EVAL_ARGS=(${NF_GENERATE_EVAL_ARGS-})
NF_GENERATE_EVAL_ARGS+=(--show-trace)

nf-eval() {
	local EVAL_FMT=$1 EVAL_ATTR=$2 EVAL_OUT=$3 \
		EVAL_ARGS=()
	shift 3

	if [[ $EVAL_ATTR != *#* ]]; then
		EVAL_ATTR="${NF_CONFIG_ROOT}#${EVAL_ATTR}"
	fi
	EVAL_ARGS=(
		"${NF_GENERATE_EVAL_ARGS[@]}"
		"$EVAL_FMT"
		"$EVAL_ATTR"
		"$@"
	)

	if [[ $EVAL_OUT != /* ]]; then
		EVAL_OUT="$NF_CONFIG_ROOT/$EVAL_OUT"
	fi

	if [[ $EVAL_FMT = --json ]]; then
		nix eval "${EVAL_ARGS[@]}" \
			| jq -M .
	else
		nix eval "${EVAL_ARGS[@]}"
	fi > "$EVAL_OUT"

}

NF_NODES=$(nix eval --json "${NF_CONFIG_ROOT}#lib.generate.nodeNames")
for node in $(jq -r '.[]' <<<"$NF_NODES"); do
	nf-eval --json "lib.generate.nodes.$node.users" "systems/$node/users.json"
	nf-eval --json "lib.generate.nodes.$node.systems" "systems/$node/systems.json"
	nf-eval --json "lib.generate.nodes.$node.extern" "systems/$node/extern.json"
	nf-eval --raw "lib.generate.nodes.$node.ssh.root.authorizedKeys.text" "systems/$node/root.authorized_keys"
done
nf-eval --json "lib.generate.systems" "ci/systems.json"

for ciconfig in "${NF_CONFIG_FILES[@]}"; do
	echo "processing ${ciconfig}..." >&2
	nix run --argstr config "$NF_CONFIG_ROOT/ci/$ciconfig" -f "$NF_INPUT_CI" run.gh-actions-generate
done
