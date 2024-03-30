ldap_args_binddn() {
	if [[ -n ${LDAPBINDDN-} ]]; then
		LDAP_ARGS+=(
			-x
			-y "$LDAPBINDPW_FILE"
		)
		if [[ -n ${LDAPBINDPW-} ]]; then
			LDAP_ARGS+=(
				-w "$LDAPBINDPW"
			)
		else
			LDAP_ARGS+=(
				-y "$LDAPBINDPW_FILE"
			)
		fi
	fi
}

ldap_args_op() {
	ldap_args_binddn
	if [[ -z ${LDAPBINDDN-} ]]; then
		LDAP_ARGS+=(-Q)
	fi
}

ldapwhoami() {
	local LDAP_ARGS=("$@")
	ldap_args_binddn
	command ldapwhoami "${LDAP_ARGS[@]}"
}

ldapsearch() {
	local LDAP_ARGS=("$@")
	ldap_args_op
	command ldapsearch -LLL -o ldif_wrap=no "${LDAP_ARGS[@]}"
}

ldapmodify() {
	local LDAP_ARGS=("$@")
	ldap_args_op
	command ldapmodify "${LDAP_ARGS[@]}"
}
