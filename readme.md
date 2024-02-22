# gensokyo.zone's Infrastructure

[![docs-badge][]][docs]

Welcome to the Palace of the Earth Spirits!

## Contribution Guidelines

### Nix

* Please use [alejandra](https://github.com/kamadorueda/alejandra) as your source formatter.
* Please check for dead code paths with [deadnix](https://github.com/astro/deadnix).
* Please use [statix](https://github.com/nerdypepper/statix) as your linter.

### Terraform

* Please use `terraform fmt` to format your Terraform work.
* Please use [tflint](https://github.com/terraform-linters/tflint) as your linter.
* Please do not merge into files by category (e.g. variables, outputs, locals).

## Build and Deploy

The `-s` disables flake checks.

```shell
# without trace
deploy -s .#<hostname>
# with trace
deploy -s .#<hostname> -- --show-trace
# deploy a fresh container
deploy -s .#<hostname> --hostname ct.local
```

## Editing Secrets

```shell
sops nixos/systems/tewi/secrets.yaml
```

### Adding Hosts

```shell
nf-sops-keyscan <hostname>
# or on a fresh container...
nf-sops-keyscan ct.local
vim .sops.yaml
```

## Proxmox

### Template

```shell
nf-tarball ct
```

[docs-badge]: https://img.shields.io/badge/API-docs-blue.svg?style=flat-square
[docs]: https://gensokyo.zone/docs/
