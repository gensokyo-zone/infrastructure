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

init_nfargs() {
	nflinksuffix="$1"
	shift

	nfargs=(
		"${NIX_BUILD_ARGS[@]}"
	)

	if [[ -n "${NF_ACTIONS_TEST_OUTLINK-}" || -n "${NF_UPDATE_CACHIX_PUSH-}" ]]; then
		nfargs+=(
			-o "${NF_ACTIONS_TEST_OUTLINK-result}$nflinksuffix"
		)
	else
		nfargs+=(
			--no-link
		)
	fi
}

nfgc() {
	if [[ -n ${NF_ACTIONS_TEST_GC-} ]]; then
		if [[ -n ${NF_UPDATE_CACHIX_PUSH-} ]]; then
			cachix push gensokyo-infrastructure "./${NF_ACTIONS_TEST_OUTLINK-result}$nflinksuffix"*/
			rm -f "./${NF_ACTIONS_TEST_OUTLINK-result}$nflinksuffix"*
		fi
		nix-collect-garbage -d
	fi
}

for nfsystem in "${NF_NIX_SYSTEMS[@]}"; do
	nfinstallable="${NF_CONFIG_ROOT}#nixosConfigurations.${nfsystem}.config.system.build.toplevel"
	init_nfargs "-$nfsystem"

	if [[ -n ${NF_ACTIONS_TEST_ASYNC-} ]]; then
		NIX_BUILD_ARGS+=("$nfinstallable")
		continue
	fi

	echo "building ${nfsystem}..." >&2

	nix build "$nfinstallable" \
		"${nfargs[@]}" \
		"$@"

	nfgc
done

if [[ -n ${NF_ACTIONS_TEST_ASYNC-} ]]; then
	init_nfargs ""
	nix build \
		"${nfargs[@]}" \
		"$@"

	nfgc
fi
