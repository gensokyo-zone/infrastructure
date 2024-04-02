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

sysaccount_password() {
	local LDAP_SYSACCOUNT_UID=$1
	local LDAP_SYSACCOUNT_PASSWORD_PATH=$2
	shift 2

	echo "updating uid=$LDAP_SYSACCOUNT_UID,$LDAP_DNSUFFIX_SYSACCOUNT ..." >&2
	if ! ldappasswd -T "$LDAP_SYSACCOUNT_PASSWORD_PATH" "uid=$LDAP_SYSACCOUNT_UID,$LDAP_DNSUFFIX_SYSACCOUNT$LDAPBASE"; then
		echo "failed to use ldappasswd, falling back to modify..." >&2
		ldapmodify <<EOF
dn: uid=$LDAP_SYSACCOUNT_UID,$LDAP_DNSUFFIX_SYSACCOUNT$LDAPBASE
changetype: modify
replace: userPassword
userPassword:< file://$LDAP_SYSACCOUNT_PASSWORD_PATH
-
delete: passwordExpirationTime
-
EOF
	fi
}

privilege_permissions() {
	local LDAP_PRIVILEGE_CN=$1 LDAP_PRIVILEGE_PERMISSION_CN
	shift 1

	echo "updating cn=$LDAP_PRIVILEGE_CN,$LDAP_DNSUFFIX_PRIVILEGE ..." >&2
	for LDAP_PRIVILEGE_PERMISSION_CN in "$@"; do
		ipa privilege-add-permission "$LDAP_PRIVILEGE_CN" --permissions="$LDAP_PRIVILEGE_PERMISSION_CN" || true
	done
}

role_privileges() {
	local LDAP_ROLE_CN=$1 LDAP_ROLE_PRIVILEGE_CN
	shift 1

	echo "updating cn=$LDAP_ROLE_CN,$LDAP_DNSUFFIX_ROLE ..." >&2
	for LDAP_ROLE_PRIVILEGE_CN in "$@"; do
		ipa role-add-privilege "$LDAP_ROLE_CN" --privileges="$LDAP_ROLE_PRIVILEGE_CN" || true
	done
}

role_members() {
	local LDAP_ROLE_CN=$1 LDAP_ROLE_MEMBER_DN LDAP_ROLE_MEMBER_CN LDAP_ROLE_MEMBER_TYPE
	shift 1

	echo "updating cn=$LDAP_ROLE_CN,$LDAP_DNSUFFIX_ROLE ..." >&2
	for LDAP_ROLE_MEMBER_DN in "$@"; do
		case $LDAP_ROLE_MEMBER_DN in
			uid=*",$LDAP_DNSUFFIX_USER"*)
				LDAP_ROLE_MEMBER_TYPE=users
				;;
			cn=*",$LDAP_DNSUFFIX_GROUP"*)
				LDAP_ROLE_MEMBER_TYPE=groups
				;;
			fqdn=*",$LDAP_DNSUFFIX_HOST"*)
				LDAP_ROLE_MEMBER_TYPE=hosts
				;;
			cn=*",$LDAP_DNSUFFIX_HOSTGROUP"*)
				LDAP_ROLE_MEMBER_TYPE=hostgroups
				;;
			krbprincipalname=*",$LDAP_DNSUFFIX_SERVICE"*)
				LDAP_ROLE_MEMBER_TYPE=services
				;;
			*)
				echo "WARN: unknown role member type for $LDAP_ROLE_MEMBER_DN" >&2
				ipa role-modify "$LDAP_ROLE_CN" --addattr=member="$LDAP_ROLE_MEMBER_DN" || true
				continue
				;;
		esac
		LDAP_ROLE_MEMBER_CN=${LDAP_ROLE_MEMBER_DN%%,*}
		LDAP_ROLE_MEMBER_CN=${LDAP_ROLE_MEMBER_CN#*=}
		ipa role-add-member "$LDAP_ROLE_CN" --${LDAP_ROLE_MEMBER_TYPE}="$LDAP_ROLE_MEMBER_CN" || true
	done
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
