# nixfiles

## Build and Deploy

```shell
:; nf-deploy build
# switch without committing to it...
:; nf-deploy test
:; nf-deploy switch
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
