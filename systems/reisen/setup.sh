#!/usr/bin/env bash
set -eu

pveversion >&2
echo "on $(hostname -f), press enter to continue" >&2
read

ROOT_AUTHORIZED_KEYS=$(grep "@$(hostname)$" /etc/pve/priv/authorized_keys)
TMP_KEYFILE=$(mktemp --tmpdir)
cat > $TMP_KEYFILE <<EOF
$ROOT_AUTHORIZED_KEYS
EOF
base64 -d >> $TMP_KEYFILE <<EOF
$INPUT_ROOT_SSH_AUTHORIZEDKEYS
EOF
cat $TMP_KEYFILE > /etc/pve/priv/authorized_keys
rm $TMP_KEYFILE

if [[ ! -d /home/tf ]]; then
	echo setting up pve terraform user... >&2
	groupadd -g 1001 tf
	useradd -u 1001 -g 1001 -d /home/tf -s /bin/bash tf
	passwd tf
	mkdir -m 0700 /home/tf
	chown tf:tf /home/tf
fi

mkdir -m 0755 -p /home/tf/.ssh
base64 -d > /home/tf/.ssh/authorized_keys <<EOF
$INPUT_TF_SSH_AUTHORIZEDKEYS
EOF
chown -R tf:tf /home/tf/.ssh

if ! pveum user list --noborder --noheader | grep -q tf@pam; then
	pveum user add tf@pam --firstname Terraform --lastname Cloud
fi

echo setting up pve terraform role... >&2
# https://pve.proxmox.com/wiki/User_Management#_privileges
TF_ROLE_PRIVS=(
	Group.Allocate Realm.AllocateUser User.Modify Permissions.Modify
	Sys.Audit
	VM.Audit VM.Allocate
	VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.PowerMgmt
	Datastore.Audit Datastore.Allocate Datastore.AllocateSpace
)
pveum role delete Terraform 2> /dev/null || true
pveum role add Terraform --privs "${TF_ROLE_PRIVS[*]}"
pveum acl modify / --users tf@pam --roles Terraform

mkdir -m 0755 -p /opt/infra/bin
base64 -d > /opt/infra/bin/putfile64 <<EOF
$INPUT_INFRA_PUTFILE64
EOF
base64 -d > /opt/infra/bin/pve <<EOF
$INPUT_INFRA_PVE
EOF
base64 -d > /opt/infra/bin/lxc-config <<EOF
$INPUT_INFRA_LXC_CONFIG
EOF
chmod 0770 /opt/infra/bin/*

cat > /etc/sudoers.d/tf <<EOF
tf ALL=(root:root) NOPASSWD: NOSETENV: /opt/infra/bin/putfile64, /opt/infra/bin/pve, /opt/infra/bin/lxc-config
EOF
