ldap_parse() {
	local LDAP_ATTR=$1 LDAP_LIMIT LDAP_LINE LDAP_COUNT=0
	shift 1
	local LDAP_LIMIT=${1-1}

	while read -r LDAP_LINE; do
		if [[ $LDAP_LIMIT -eq 0 ]]; then
			break
		fi
		if [[ $LDAP_LINE = "$LDAP_ATTR:: "* ]]; then
			printf '%s\n' "$LDAP_LINE" | cut -d ' ' -f 2- | base64 -d
		elif [[ $LDAP_LINE = "$LDAP_ATTR: "* ]]; then
			printf '%s\n' "$LDAP_LINE" | cut -d ' ' -f 2-
		else
			continue
		fi
		LDAP_COUNT=$((LDAP_COUNT+1))
		LDAP_LIMIT=$((LDAP_LIMIT-1))
	done
	if [[ $LDAP_COUNT -eq 0 ]]; then
		echo "$LDAP_ATTR not found" >&2
		return 1
	fi
}

smbsync_group() {
	local LDAP_GROUP_CN=$1 SMB_GROUP_DATA SMB_GROUP_SID
	shift 1

	echo "updating cn=$LDAP_GROUP_CN,$LDAP_DNSUFFIX_GROUP ..." >&2
	SMB_GROUP_DATA=$(ldapsearch -z1 \
		-b "$LDAP_DNSUFFIX_GROUP$LDAPBASE" \
		"(&(cn=$LDAP_GROUP_CN)(objectClass=posixgroup))" \
		objectClass ipaNTSecurityIdentifier
	)
	SMB_GROUP_SID=$(ldap_parse ipaNTSecurityIdentifier <<< "$SMB_GROUP_DATA")
	ldapmodify <<EOF
dn: cn=$LDAP_GROUP_CN,$LDAP_DNSUFFIX_GROUP$LDAPBASE
changetype: modify
replace: sambaSID
sambaSID: $SMB_GROUP_SID
-
EOF
}

smbsync_user() {
	local LDAP_USER_UID=$1 SMB_USER_DATA SMB_USER_SID SMB_USER_NTPASS
	shift 1

	echo "updating uid=$LDAP_USER_UID,$LDAP_DNSUFFIX_USER ..." >&2
	SMB_USER_DATA=$(ldapsearch -z1 \
		-b "$LDAP_DNSUFFIX_USER$LDAPBASE" \
		"(&(uid=$LDAP_USER_UID)(objectClass=posixaccount))" \
		objectClass ipaNTSecurityIdentifier ipaNTHash ipaUserAuthType memberOf
	)
	SMB_USER_SID=$(ldap_parse ipaNTSecurityIdentifier <<< "$SMB_USER_DATA")
	SMB_USER_NTPASS=$(ldap_parse ipaNTHash <<< "$SMB_USER_DATA" | xxd -p)
	SMB_USER_NTPASS=${SMB_USER_NTPASS^^}
	ldapmodify <<EOF
dn: uid=$LDAP_USER_UID,$LDAP_DNSUFFIX_USER$LDAPBASE
changetype: modify
replace: sambaSID
sambaSID: $SMB_USER_SID
-
replace: sambaNTPassword
sambaNTPassword: $SMB_USER_NTPASS
-
EOF
}
