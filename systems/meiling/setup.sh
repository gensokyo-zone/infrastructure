mkshared-nix() {
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
}

#mkshared-nix
