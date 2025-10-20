{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkDefault;
in {
  # NOTE: requires manual post-install setup...
  # :; kinit admin
  # :; ipa-join --hostname=${config.networking.fqdn} -k /tmp/krb5.keytab -s idp.${domain}
  # then to authorize it for a specific service...
  # :; ipa-getkeytab -k /tmp/krb5.keytab -s idp.${domain} -p ${serviceName}/idp.${domain}@${toUpper domain}
  # once the sops secret has been updated with keytab...
  # :; systemctl restart sssd

  imports = [
    ./krb5.nix
    ./sssd.nix
  ];

  config = {
    security.ipa = {
      enable = mkDefault true;
      overrideConfigs = {
        krb5 = mkDefault false;
        sssd = mkDefault false;
        openldap = false;
      };
      openldap.settings.tls_cacert = "/etc/ssl/certs/ca-bundle.crt";
    };
  };
}
