#!/usr/bin/env bash
set -eu

ARG_GAME_SRC=$1
ARG_GAME_VERSION=$2
ARG_SHARED_DATA=$3
ARG_USER_DATA=$4
shift 4

if ! [[ -e "$ARG_GAME_SRC/$ARG_GAME_VERSION/Beat Saber.exe" ]]; then
	echo unexpected game src >&2
	exit 1
fi

ln -srf "$ARG_GAME_SRC/$ARG_GAME_VERSION/"*.{exe,dll} ./
ln -srf "$ARG_GAME_SRC/$ARG_GAME_VERSION/"{MonoBleedingEdge,Plugins} ./
rm "Beat Saber.exe"
cp "$ARG_GAME_SRC/$ARG_GAME_VERSION/Beat Saber.exe" ./
chmod 0775 "Beat Saber.exe"

BSDATA="Beat Saber_Data"
mkdir -pm2775 "$BSDATA"
ln -srf "$ARG_GAME_SRC/$ARG_GAME_VERSION/$BSDATA/"* "$BSDATA/" || true
ln -srf "$ARG_SHARED_DATA/CustomLevels" "$BSDATA/"
rm -f "$BSDATA/Managed"

mkdir -pm2775 UserData

ln -srf "$ARG_SHARED_DATA/"{CustomAvatars,CustomNotes,CustomPlatforms,CustomSabers,CustomWalls,Playlists} ./
for shareddir in DynamicOpenVR IPA Libs Logs Plugins "$BSDATA/Managed" UserData/SongCore; do
	shareddirsrc="$ARG_SHARED_DATA/$ARG_GAME_VERSION/$shareddir"
	if [[ ! -e $shareddirsrc ]]; then
		mkdir -pm2775 "$shareddirsrc"
		if [[ $shareddir = */Managed ]]; then
			cp "$ARG_GAME_SRC/$ARG_GAME_VERSION/$BSDATA/Managed/"* "$shareddirsrc/" || true
			chmod 0775 "$shareddirsrc/"*.dll || true
		fi
	fi
	ln -srf "$shareddirsrc" "./$(dirname "$shareddir")"
done
for sharedfile in IPA.exe IPA.exe.config IPA.runtimeconfig.json winhttp.dll; do
	sharedfilesrc="$ARG_SHARED_DATA/$ARG_GAME_VERSION/$sharedfile"
	if [[ ! -e "$sharedfilesrc" ]]; then
		mkdir -pm2775 "$(dirname "$sharedfilesrc")"
		if [[ $sharedfile = *.json ]]; then
			echo '{}' > "$sharedfilesrc"
		else
			touch "$sharedfilesrc"
		fi
		chmod 0775 "$sharedfilesrc" || true
	fi
	ln -f "$sharedfilesrc" ./
done

for sharedfile in "Beat Saber IPA.json"; do
	sharedfilesrc="$ARG_SHARED_DATA/$ARG_GAME_VERSION/UserData/$sharedfile"
	if [[ ! -e "$sharedfilesrc" ]]; then
		mkdir -pm2775 "$(dirname "$sharedfilesrc")"
		if [[ $sharedfile = *.json ]]; then
			echo '{}' > "$sharedfilesrc"
		else
			touch "$sharedfilesrc"
		fi
	fi
	ln -f "$sharedfilesrc" "UserData/$(dirname "$sharedfile")"
done
ln -f "$ARG_SHARED_DATA/UserData/"*.{json,ini,proto,etag} UserData/
ln -srf "$ARG_SHARED_DATA/UserData/"{ScoreSaber,Chroma,Nya,SongRankedBadge,HitScoreVisualizer}/ UserData/

SFDATA="UserData/Saber Factory"
mkdir -pm2775 "$SFDATA"
ln -srf "$ARG_SHARED_DATA/$SFDATA/"*/ "$SFDATA/"
ln -srf "$ARG_USER_DATA/$SFDATA/"*/ "$SFDATA/"
ln -f "$ARG_USER_DATA/$SFDATA/"*.json "$SFDATA/"

for userdir in Camera2 DrinkWater Enhancements; do
	userdirsrc="$ARG_USER_DATA/UserData/$userdir"
	if [[ ! -e $userdirsrc ]]; then
		mkdir -pm3775 "$userdirsrc"
	fi
	ln -srf "$userdirsrc" UserData/
done
ln -f "$ARG_USER_DATA/UserData/"*.{json,ini,dat} UserData/
