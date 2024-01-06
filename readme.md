# nixfiles

## Build and Deploy

```shell
:; export NF_HOST=tewi
:; nf-deploy build
# switch without committing to it...
:; nf-deploy test
# then deploy..!
:; nf-deploy switch
```

The above is just a convenience wrapper around `nixos-rebuild`:

```shell
:; nixos-rebuild switch --flake .#tewi --target-host tewi --use-remote-sudo
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
NF_HOST=reisen-ct nf-deploy tarball
```
