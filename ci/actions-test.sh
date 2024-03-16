#!/usr/bin/env bash
set -eu

if [[ ${GITHUB_ACTIONS-} = true && ${RUNNER_NAME-} = "Github Actions"* ]]; then
	# low disk space available on public runners...
	echo "enabled GC between builds due to restricted disk space..." >&2
	export NF_ACTIONS_TEST_GC=1
fi

NIX_BUILD_ARGS=(
	--show-trace
)

for nfsystem in "${NF_NIX_SYSTEMS[@]}"; do
	nfargs=(
		"${NIX_BUILD_ARGS[@]}"
	)
	if [[ -n "${NF_ACTIONS_TEST_OUTLINK-}" || -n "${NF_UPDATE_CACHIX_PUSH-}" ]]; then
		nfargs+=(
			-o "${NF_ACTIONS_TEST_OUTLINK-result}-$nfsystem"
		)
	else
		nfargs+=(
			--no-link
		)
	fi

	echo "building ${nfsystem}..." >&2

	nix build \
		"${NF_CONFIG_ROOT}#nixosConfigurations.${nfsystem}.config.system.build.toplevel" \
		"${nfargs[@]}" \
		"$@"

	if [[ -n "${NF_ACTIONS_TEST_GC-}" ]]; then
		if [[ -n "${NF_UPDATE_CACHIX_PUSH-}" ]]; then
			cachix push gensokyo-infrastructure "./${NF_ACTIONS_TEST_OUTLINK-result}-$nfsystem"*/
			rm -f "./${NF_ACTIONS_TEST_OUTLINK-result}-$nfsystem"*
		fi
		nix-collect-garbage -d
	fi
done
