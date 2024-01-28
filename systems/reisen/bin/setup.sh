#!/usr/bin/env bash
set -eu

if [[ ! -d /home/tf ]]; then
	echo setting up pve terraform user... >&2
	groupadd -g 1001 tf
	useradd -u 1001 -g 1001 -d /home/tf -s /bin/bash tf
	passwd tf
	pveum user add tf@pam --firstname Terraform --lastname Cloud
	pveum acl modify / --users tf@pam --roles PVEVMAdmin
	mkdir -p /home/tf/.ssh
	cat > /home/tf/.ssh/authorized_keys <<<"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBFobUpp90cBjtqBfHlw49WohhLFeExAmOmHOnCentx+ hakurei-tf-proxmox"
	chown -R tf:tf /home/tf
	chmod -R og= /home/tf/.ssh
fi

mkdir -p /opt/infra/bin
base64 -d > /opt/infra/bin/putfile64 <<<"$INPUT_INFRA_PUTFILE64"
base64 -d > /opt/infra/bin/pve <<<"$INPUT_INFRA_PVE"
base64 -d > /opt/infra/bin/lxc-config <<<"$INPUT_INFRA_LXC_CONFIG"
chmod u+x /opt/infra/bin/*
chmod og-rwx /opt/infra/bin/*

cat > /etc/sudoers.d/tf <<EOF
tf ALL=(root:root) NOPASSWD: NOSETENV: /opt/infra/bin/putfile64, /opt/infra/bin/pve, /opt/infra/bin/lxc-config
EOF
