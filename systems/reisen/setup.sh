mkkyuuto() {
	local KYUUTO_MOUNTNAME KYUUTO_ARGS=()
	KYUUTO_NAME=$1
	KYUUTO_ARGS=("$2" "$3" "$4")
	shift 4
	KYUUTO_MOUNTNAME=${KYUUTO_MOUNT-$KYUUTO_NAME}
	mkzfs "/mnt/kyuuto-$KYUUTO_MOUNTNAME" "${KYUUTO_ARGS[@]}" "kyuuto/$KYUUTO_NAME" "$@"
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
mkcache taskchampion 100917 100917 0750
mkcache minecraft 100913 100913 0750
mkcache plex 0 0 0755
for plexcache in Logs CrashReports Diagnostics Cache Caches Drivers Codecs Scanners Updates mesa_shader_cache; do
	if [[ ! -d /rpool/caches/plex/$plexcache ]]; then
		mkdir /rpool/caches/plex/$plexcache
	fi
	chown 100193:100193 /rpool/caches/plex/$plexcache
	chmod 0775 /rpool/caches/plex/$plexcache
done
if [[ ! -d /rpool/caches/plex/tautulli/cache ]]; then
	mkdir -p /rpool/caches/plex/tautulli/cache
fi
chown 100195:65534 /rpool/caches/plex/tautulli/cache
chmod 0755 /rpool/caches/plex/tautulli/cache

mkshared hass 100286 100286 0700
mkshared grocy 100911 100060 0700
mkshared barcodebuddy 100912 100060 0700
mkshared kanidm 100994 100993 0700
mkshared mosquitto 100246 100246 0700
mkshared plex 100193 100193 0750
mkshared postgresql 100071 100071 0750
mkshared taskchampion 100917 100917 0750
mkshared unifi 100990 100990 0750
mkshared zigbee2mqtt 100317 100317 0700
mkshared vaultwarden 100915 100915 0750
mkshared minecraft 100913 100913 0750
mkshared minecraft/bedrock 100913 100913 0750
mkshared minecraft/java 100913 100913 0750

mkkyuuto data 0 0 0755 -o compression=on
mkkyuuto data/minecraft 0 8126 0775
if [[ ! -d /mnt/kyuuto-data/minecraft/simplebackups ]]; then
	mkdir -p /mnt/kyuuto-data/minecraft/simplebackups
fi
chown 100913:8126 /mnt/kyuuto-data/minecraft/simplebackups
chmod 0775 /mnt/kyuuto-data/minecraft/simplebackups

mkkyuuto data/systems 0 0 0775
nfsystemroot=/mnt/kyuuto-data/systems
for nfsystem in gengetsu mugetsu goliath; do
	mkkyuuto data/systems/$nfsystem 0 0 0750

	if [[ ! -d $nfsystemroot/$nfsystem/fs ]]; then
		mkdir $nfsystemroot/$nfsystem/fs
	fi
	chown 0:0 $nfsystemroot/$nfsystem/fs
	chmod 0755 $nfsystemroot/$nfsystem/fs

	for nfsystemfs in root boot; do
		KYUUTO_MOUNT=data/systems/$nfsystem/fs/$nfsystemfs mkkyuuto data/systems/$nfsystem/$nfsystemfs 0 0 0755
	done
done
