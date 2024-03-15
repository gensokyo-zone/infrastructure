{ inputs, pkgs, config, lib, ... }: let
  inherit (inputs.self.lib.lib) mkBaseDn;
  inherit (lib.modules) mkIf mkForce mkDefault;
  inherit (lib.strings) toUpper splitString concatMapStringsSep;
  inherit (config.networking) domain;
  cfg = config.security.ipa;
  baseDn = mkBaseDn domain;
  caPem = pkgs.fetchurl {
    name = "idp.${domain}.ca.pem";
    url = "https://freeipa.${domain}/ipa/config/ca.crt";
    sha256 = "sha256-PKjnjn1jIq9x4BX8+WGkZfj4HQtmnHqmFSALqggo91o=";
  };
in {
  # NOTE: requires manual post-install setup...
  # :; kinit admin
  # :; ipa-join --hostname=${config.networking.fqdn} -k /tmp/krb5.keytab -s idp.${domain}
  # then to authorize it for a specific service...
  # :; ipa-getkeytab -k /tmp/krb5.keytab -s idp.${domain} -p ${serviceName}/idp.${domain}@${toUpper domain}
  # once the sops secret has been updated with keytab...
  # :; systemctl restart sssd
  config = {
    security.ipa = {
      enable = mkDefault true;
      certificate = mkDefault caPem;
      basedn = mkDefault baseDn;
      chromiumSupport = mkDefault false;
      domain = mkDefault domain;
      realm = mkDefault (toUpper domain);
      server = mkDefault "idp.${domain}";
      ifpAllowedUids = [
        "root"
      ] ++ config.users.groups.wheel.members;
      dyndns.enable = mkDefault false;
    };
    networking.extraHosts = mkIf cfg.enable ''
      10.1.1.46 idp.${domain}
    '';
    systemd.services.auth-rpcgss-module = mkIf (cfg.enable && !config.boot.modprobeConfig.enable) {
      serviceConfig.ExecStart = mkForce [
        ""
        "${pkgs.coreutils}/bin/true"
      ];
    };
    sops.secrets = {
      krb5-keytab = mkIf cfg.enable {
        mode = "0400";
        path = "/etc/krb5.keytab";
      };
    };
  };
}
