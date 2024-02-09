{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (lib.lists) any;
  inherit (lib.strings) hasInfix concatMapStringsSep splitString;
  cfg =  config.services.samba;
  hasIpv4 = any (hasInfix ".") config.systemd.network.networks.eth0.address or [ ];
in {
  services.samba = {
    enable = mkDefault true;
    enableWinbindd = mkDefault false;
    enableNmbd = mkDefault hasIpv4;
    securityType = mkDefault "user";
    ldap = {
      url = mkDefault "ldaps://ldap.local.${config.networking.domain}";
      baseDn = mkDefault (concatMapStringsSep "," (part: "dc=${part}") (splitString "." config.networking.domain));
    };
    usershare = {
      group = mkDefault "peeps";
    };
    guest = {
      enable = mkDefault true;
      user = mkDefault "guest";
    };
    passdb.smbpasswd.path = mkDefault config.sops.secrets.smbpasswd.path;
    settings = {
      workgroup = "GENSOKYO";
      "local master" = false;
      "preferred master" = false;
      "winbind offline logon" = true;
      "winbind scan trusted domains" = false;
      "winbind use default domain" = true;
      "domain master" = false;
      "valid users" = [ "@peeps" ];
      "remote announce" = mkIf hasIpv4 [
        "10.1.1.255/${cfg.settings.workgroup}"
      ];
    };
  };

  services.samba-wsdd = {
    enable = mkIf cfg.enable (mkDefault true);
    hostname = mkDefault config.networking.hostName;
  };

  sops.secrets.smbpasswd = {
    sopsFile = mkDefault ./secrets/samba.yaml;
    #path = "/var/lib/samba/private/smbpasswd";
  };
}
