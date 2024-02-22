#!/usr/bin/env bash
set -eu

nf-statix check "$@" &&
	nf-deadnix -f "$@"
