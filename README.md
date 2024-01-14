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
