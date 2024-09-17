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

base64 -d > /etc/subuid <<EOF
$INPUT_SUBUID
EOF
base64 -d > /etc/subgid <<EOF
$INPUT_SUBGID
EOF

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

pveum acl delete / --users tf@pam --roles Terraform 2> /dev/null || true
pveum role delete Terraform 2> /dev/null || true

if ! pveum user list --noborder --noheader 2> /dev/null | grep -q tf@pam; then
	pveum user add tf@pam --firstname Terraform --lastname Cloud
fi

echo setting up pve terraform role... >&2
# https://pve.proxmox.com/wiki/User_Management#_privileges
TF_ROLE_PRIVS=(
	Group.Allocate Realm.AllocateUser User.Modify Permissions.Modify
	Sys.Audit Sys.Modify # Sys.Console Sys.Incoming Sys.PowerMgmt Sys.Syslog
	VM.Audit VM.Allocate VM.PowerMgmt
	VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options
	VM.Backup VM.Clone VM.Migrate VM.Snapshot VM.Snapshot.Rollback VM.Console VM.Monitor
	SDN.Audit SDN.Use SDN.Allocate
	Datastore.Audit Datastore.Allocate Datastore.AllocateSpace # Datastore.AllocateTemplate
	Mapping.Audit Mapping.Use Mapping.Modify
	Pool.Audit # Pool.Allocate
)
pveum role add Terraform --privs "${TF_ROLE_PRIVS[*]}"
pveum acl modify / --users tf@pam --roles Terraform

INFRABIN=/opt/infra/bin
WRAPPERBIN=/opt/infra/sbin
SUDOERS_INFRABINS=
rm -f "$INFRABIN/"* "$WRAPPERBIN/"*
mkdir -m 0755 -p "$INFRABIN" "$WRAPPERBIN"
for infrabin in putfile64 pve mkpam ct-config; do
	infrainput="${infrabin//-/_}"
	infrainput="INPUT_INFRA_${infrainput^^}"
	printf '%s\n' "${!infrainput}" | base64 -d > "$WRAPPERBIN/$infrabin"
	chmod 0750 "$WRAPPERBIN/$infrabin"

	printf '#!/bin/bash\nsudo "%s" "$@"\n' "$WRAPPERBIN/$infrabin" > "$INFRABIN/$infrabin"
	chmod 0755 "$INFRABIN/$infrabin"

	SUDOERS_WRAPPERS="${SUDOERS_WRAPPERS-}${SUDOERS_WRAPPERS:+, }$WRAPPERBIN/$infrabin"
done

# provider also needs to be able to run:
# sudo qm importdisk VMID $(sudo pvesm path local:iso/ISO.iso) DATASTORE -format qcow2
# sudo qm set VMID -scsi0 DATASTORE:disk,etc
# sudo qm resize VMID scsi0 SIZE
SUDOERS_TF="/usr/sbin/pvesm, /usr/sbin/qm"

echo 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' > /home/tf/.bash_profile
echo "export PATH=\$PATH:$INFRABIN" > /home/tf/.bashrc
chown tf:tf /home/tf/.bash{rc,_profile}

cat > /etc/sudoers.d/tf <<EOF
tf ALL=(root:root) NOPASSWD: NOSETENV: $SUDOERS_WRAPPERS, $SUDOERS_TF
EOF

if [[ ! -d /rpool/shared ]]; then
	zfs create rpool/shared
fi

if [[ ! -d /rpool/caches ]]; then
	zfs create rpool/caches
fi

mkzfs() {
	local ZFS_PATH ZFS_MODE ZFS_OWNER ZFS_GROUP
	ZFS_PATH=$1
	ZFS_OWNER=$2
	ZFS_GROUP=$3
	ZFS_MODE=$4
	shift 4

	ZFS_NAME=${ZFS_PATH#/}
	if [[ $# -gt 0 ]]; then
		ZFS_NAME=$1
		shift
	fi

	ZFS_ARGS=("$@")

	if [[ $ZFS_NAME != ${ZFS_PATH#/} ]]; then
		ZFS_ARGS+=(-o "mountpoint=$ZFS_PATH")
	fi

	if [[ ! -d "$ZFS_PATH" ]]; then
		zfs create "$ZFS_NAME" ${ZFS_ARGS[@]+"${ZFS_ARGS[@]}"}
	fi
	chmod "$ZFS_MODE" "$ZFS_PATH"
	chown "$ZFS_OWNER:$ZFS_GROUP" "$ZFS_PATH"
}

mkshared() {
	local SHARED_PATH=$1
	shift
	mkzfs "/rpool/shared/$SHARED_PATH" "$@"
}

mkcache() {
	local CACHE_PATH=$1
	shift
	mkzfs "/rpool/caches/$CACHE_PATH" "$@"
}

mkkyuuto() {
	local KYUUTO_PATH KYUUTO_ARGS=()
	KYUUTO_NAME=$1
	KYUUTO_ARGS=("$2" "$3" "$4")
	shift 4
	mkzfs "/mnt/kyuuto-$KYUUTO_NAME" "${KYUUTO_ARGS[@]}" "kyuuto/$KYUUTO_NAME" "$@"
}

mkshared nix 0 0 0755
if [[ ! -d /rpool/shared/nix/store ]]; then
	zfs create -o compression=zstd rpool/shared/nix/store
fi
if [[ ! -d /rpool/shared/nix/var ]]; then
	mkdir /rpool/shared/nix/var
fi
chown 100000:30000 /rpool/shared/nix/store
chmod 1775 /rpool/shared/nix/store
chown 100000:100000 /rpool/shared/nix/var

mkcache zigbee2mqtt 100317 100317 0700
mkcache plex 0 0 0755
if [[ ! -d /rpool/caches/plex/Cache ]]; then
	mkdir /rpool/caches/plex/Cache
fi
if [[ ! -d /rpool/caches/plex/tautulli/cache ]]; then
	mkdir -p /rpool/caches/plex/tautulli/cache
fi
chown 100193:100193 /rpool/caches/plex/Cache
chmod 0775 /rpool/caches/plex/Cache
chown 100195:65534 /rpool/caches/plex/tautulli/cache
chmod 0755 /rpool/caches/plex/tautulli/cache

mkshared hass 100286 100286 0700
mkshared grocy 100911 100060 0700
mkshared barcodebuddy 100912 100060 0700
mkshared kanidm 100994 100993 0700
mkshared mosquitto 100246 100246 0700
mkshared plex 100193 100193 0750
mkshared postgresql 100071 100071 0750
mkshared unifi 100990 100990 0750
mkshared zigbee2mqtt 100317 100317 0700
mkshared vaultwarden 100915 100915 0750
mkshared minecraft 100913 100913 0750
mkshared minecraft/bedrock 100913 100913 0750
mkshared minecraft/katsink 100913 100913 0750

mkkyuuto data 0 0 0755 -o compression=on
mkkyuuto data/minecraft 0 8126 0775
if [[ ! -d /mnt/kyuuto-data/minecraft/simplebackups ]]; then
	mkdir -p /mnt/kyuuto-data/minecraft/simplebackups
fi
chown 100913:8126 /mnt/kyuuto-data/minecraft/simplebackups
chmod 0775 /mnt/kyuuto-data/minecraft/simplebackups

ln -sf /lib/systemd/system/auth-rpcgss-module.service /etc/systemd/system/
mkdir -p /etc/systemd/system/auth-rpcgss-module.service.d
ln -sf /etc/systemd/system/auth-rpcgss-module.service /etc/systemd/system/multi-user.target.wants/
base64 -d > /etc/systemd/system/auth-rpcgss-module.service.d/overrides.conf <<EOF
$INPUT_AUTHRPCGSS_OVERRIDES
EOF
