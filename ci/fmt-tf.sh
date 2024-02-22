#!/usr/bin/env bash
set -eu

exec terraform fmt -recursive "$@"
