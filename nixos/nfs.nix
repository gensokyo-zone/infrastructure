{
  config,
  lib,
  access,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (lib.lists) optional;
  inherit (lib.strings) concatStringsSep concatMapStringsSep splitString;
  cfg = config.services.nfs;
  openPorts = [
    (mkIf cfg.server.enable 2049)
    (mkIf config.services.rpcbind.enable 111)
    (mkIf (cfg.server.statdPort != null) cfg.server.statdPort)
    (mkIf (cfg.server.lockdPort != null) cfg.server.lockdPort)
    (mkIf (cfg.server.mountdPort != null) cfg.server.mountdPort)
  ];
  enableLdap = false;
  system = access.systemFor "tei";
  inherit (system.services) kanidm;
in {
  services.nfs = {
    server = {
      enable = mkDefault true;
      statdPort = mkDefault 4000;
      lockdPort = mkDefault 4001;
      mountdPort = mkDefault 4002;
    };
    idmapd.settings = {
      General.Domain = mkDefault config.networking.domain;
      Translation.GSS-Methods = concatStringsSep "," (
        [ "static" ]
        ++ optional enableLdap "umich_ldap"
        ++ [ "nsswitch" ]
      );
      Static = {
      };
      UMICH_SCHEMA = mkIf enableLdap {
        LDAP_server = "ldap.local.${config.networking.domain}";
        LDAP_use_ssl = true;
        LDAP_ca_cert = "/etc/ssl/certs/ca-bundle.crt";
        LDAP_base = kanidm.server.ldap.baseDn;
        NFSv4_person_objectclass = "account";
        NFSv4_group_objectclass = "group";
        NFSv4_name_attr = "name";
        NFSv4_group_attr = "name";
        NFSv4_uid_attr = "gidnumber";
        NFSv4_gid_attr = "gidnumber";
        LDAP_canonicalize_name = false;
      };
    };
  };
  networking.firewall.interfaces.local = {
    allowedTCPPorts = openPorts;
    allowedUDPPorts = openPorts;
  };
}
