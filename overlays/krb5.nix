final: prev: {
  krb5-ldap = final.krb5.override {
    withLdap = true;
  };
}
