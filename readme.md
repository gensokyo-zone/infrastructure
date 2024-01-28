# gensokyo.zone's Infrastructure

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
```

## Editing Secrets

```shell
sops nixos/systems/tewi/secrets.yaml
```

### Adding Hosts

```shell
NF_ADDR=10.1.1.xxx nf-deploy sops-keyscan
vim .sops.yaml
```

## Proxmox

### Template

```shell
NF_HOST=ct nf-deploy tarball
```
