{
  config,
  lib,
  inputs,
  pkgs,
  ...
}: let
  inherit (inputs.self.lib.lib) mkAlmostOptionDefault;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkBefore mkAfter mkOptionDefault;
  inherit (lib.attrsets) mapAttrs' mapAttrsToList listToAttrs nameValuePair;
  inherit (lib.lists) concatLists;
  inherit (lib.strings) toUpper hasPrefix concatMapStringsSep concatStringsSep;
  inherit (lib.trivial) flip;
  inherit (config.services) samba-wsdd;
  cfg = config.services.samba;
  settingValue = value:
    if builtins.isList value
    then concatMapStringsSep ", " settingValue value
    else if value == true
    then "yes"
    else if value == false
    then "no"
    else toString value;
in {
  options.services.samba = with lib.types; let
    settingPrimitive = oneOf [str int bool];
    settingType = oneOf [settingPrimitive (listOf settingPrimitive)];
  in {
    domain = {
      netbiosName = mkOption {
        type = nullOr str;
        default = null;
        defaultText = "networking.hostName";
      };
      netbiosName' = mkOption {
        type = str;
      };
      isWorkgroup = mkOption {
        type = bool;
      };
      name = mkOption {
        type = nullOr str;
        default = null;
      };
      netbiosHostAddresses = mkOption {
        type = attrsOf (listOf str);
        default = { };
      };
      lmhosts = mkOption {
        type = attrsOf str;
        default = { };
      };
    };
    ldap = {
      enable = mkEnableOption "LDAP";
      passdb = {
        enable = mkEnableOption "LDAP authentication" // {
          default = true;
        };
        backend = mkOption {
          type = enum [ "ldapsam" "ipasam" ];
          default = "ldapsam";
        };
      };
      idmap = {
        enable = mkEnableOption "LDAP users" // {
          default = true;
        };
        domain = mkOption {
          type = str;
          default = "*";
        };
      };
      url = mkOption {
        type = str;
      };
      baseDn = mkOption {
        type = str;
      };
      adminDn = mkOption {
        type = nullOr str;
        default = "name=anonymous,${cfg.ldap.baseDn}";
      };
      adminPasswordPath = mkOption {
        type = nullOr path;
        default = null;
      };
    };
    kerberos = {
      enable = mkEnableOption "krb5";
      realm = mkOption {
        type = str;
      };
      keytabPath = mkOption {
        type = nullOr path;
        default = null;
      };
    };
    tls = {
      enable = mkEnableOption "tls" // {
        default = cfg.tls.certPath != null;
      };
      peer.enable = mkEnableOption "peer verification" // {
        default = cfg.tls.caPath != null;
      };
      useACMECert = mkOption {
        type = nullOr str;
        default = null;
      };
      certPath = mkOption {
        type = nullOr path;
        default = null;
      };
      keyPath = mkOption {
        type = nullOr path;
        default = null;
      };
      caPath = mkOption {
        type = nullOr path;
        default = null;
      };
      crlPath = mkOption {
        type = nullOr path;
        default = null;
      };
    };
    usershare = {
      enable = mkEnableOption "usershare";
      group = mkOption {
        type = str;
        default = "users";
      };
      path = mkOption {
        type = path;
        default = "/var/lib/samba/usershares";
      };
      templateShare = mkOption {
        type = str;
        default = "usershare-template";
      };
    };
    guest = {
      enable = mkEnableOption "guest account";
      user = mkOption {
        type = str;
        default = "nobody";
      };
    };
    idmap = let
      idmapModule = {
        config,
        name,
        ...
      }: {
        options = {
          backend = mkOption {
            type = str;
          };
          domain = mkOption {
            type = str;
            default = name;
          };
          range = {
            min = mkOption {
              type = int;
              default = 1000;
            };
            max = mkOption {
              type = int;
              default = 65534;
            };
          };
          readOnly = mkOption {
            type = bool;
            default = true;
          };
          settings = mkOption {
            type = attrsOf settingType;
            default = {};
          };
        };
        config = {
          settings = {
            backend = mkOptionDefault config.backend;
            "read only" = mkOptionDefault config.readOnly;
            range = mkOptionDefault "${toString config.range.min} - ${toString config.range.max}";
          };
        };
      };
    in {
      domains = mkOption {
        type = attrsOf (submodule idmapModule);
        default = {
          nss = {
            backend = "nss";
            domain = "*";
          };
        };
      };
    };
    passdb.smbpasswd.path = mkOption {
      type = nullOr path;
      default = null;
    };
    settings = mkOption {
      type = attrsOf settingType;
      default = {};
    };
  };

  config = {
    services.samba = {
      package = mkIf cfg.ldap.enable (mkAlmostOptionDefault (
        if cfg.ldap.passdb.enable && cfg.ldap.passdb.backend == "ipasam" then pkgs.samba-ipa else pkgs.samba-ldap
      ));
      domain = {
        isWorkgroup = mkOptionDefault (cfg.securityType != "domain" && cfg.securityType != "ads");
        netbiosName' = let
          name = if cfg.domain.netbiosName != null then cfg.domain.netbiosName else config.networking.hostName;
        in mkOptionDefault (if cfg.domain.isWorkgroup then toUpper name else name);
        netbiosHostAddresses = mkIf (cfg.domain.netbiosName != null) {
          ${cfg.domain.netbiosName'} = [ "127.0.0.1" "::1" ];
        };
        lmhosts = let
          addrs = mapAttrsToList (name: map (flip nameValuePair name)) cfg.domain.netbiosHostAddresses;
        in listToAttrs (concatLists addrs);
      };
      ldap = {
        adminPasswordPath = mkIf (cfg.ldap.adminDn != null && hasPrefix "name=anonymous," cfg.ldap.adminDn) (mkAlmostOptionDefault (
          pkgs.writeText "smb-ldap-anonymous" "anonymous"
        ));
        idmap.domain = mkIf (cfg.domain.name != null) (mkAlmostOptionDefault cfg.domain.name);
      };
      tls = let
        cert = config.security.acme.certs.${cfg.tls.useACMECert};
      in {
        certPath = mkIf (cfg.tls.useACMECert != null) (mkAlmostOptionDefault "${cert.directory}/fullchain.pem");
        keyPath = mkIf (cfg.tls.useACMECert != null) (mkAlmostOptionDefault "${cert.directory}/key.pem");
        caPath = mkIf (cfg.kerberos.enable && config.security.ipa.enable) (mkAlmostOptionDefault "${config.security.ipa.certificate}");
      };
      idmap.domains = mkMerge [
        (mkIf (cfg.ldap.enable && cfg.ldap.idmap.enable) {
          ldap = {
            backend = mkOptionDefault "ldap";
            domain = mkAlmostOptionDefault cfg.ldap.idmap.domain;
            settings = {
              ldap_url = mkOptionDefault cfg.ldap.url;
            };
          };
        })
      ];
      settings = mkMerge ([
        {
          "use sendfile" = mkOptionDefault true;
          "mdns name" = mkOptionDefault "mdns";
          "name resolve order" = mkOptionDefault [ "lmhosts" "host" "bcast" ];
          workgroup = mkIf (cfg.domain.name != null) (mkOptionDefault cfg.domain.name);
          "netbios name" = mkIf (cfg.domain.netbiosName != null) (mkOptionDefault cfg.domain.netbiosName);
        }
        (mkIf (cfg.passdb.smbpasswd.path != null) {
          "passdb backend" = mkOptionDefault "smbpasswd:${cfg.passdb.smbpasswd.path}";
        })
        (mkIf cfg.ldap.enable {
          "ldap ssl" = mkIf (hasPrefix "ldaps://" cfg.ldap.url) (mkOptionDefault "off");
          "ldap admin dn" = mkIf (cfg.ldap.adminDn != null) (mkOptionDefault cfg.ldap.adminDn);
          "ldap suffix" = mkOptionDefault cfg.ldap.baseDn;
        })
        (mkIf cfg.kerberos.enable {
          "realm" = mkOptionDefault cfg.kerberos.realm;
          "kerberos method" = mkOptionDefault (
            if cfg.kerberos.keytabPath != null then "dedicated keytab"
            else "system keytab"
          );
          "dedicated keytab file" = mkIf (cfg.kerberos.keytabPath != null) (mkOptionDefault
            "FILE:${cfg.kerberos.keytabPath}"
          );
          "kerberos encryption types" = mkOptionDefault "strong";
          "create krb5 conf" = mkOptionDefault false;
        })
        (mkIf cfg.enableWinbindd {
          "winbind nss info" = mkOptionDefault "rfc2307";
          "winbind use default domain" = mkOptionDefault true;
        })
        (mkIf cfg.tls.enable {
          "tls enabled" = mkOptionDefault true;
          "tls verify peer" = mkIf cfg.tls.peer.enable (mkOptionDefault "ca_and_name_if_available");
          "tls certfile" = mkIf (cfg.tls.certPath != null) (mkOptionDefault cfg.tls.certPath);
          "tls keyfile" = mkIf (cfg.tls.keyPath != null) (mkOptionDefault cfg.tls.keyPath);
          "tls cafile" = mkIf (cfg.tls.caPath != null) (mkOptionDefault cfg.tls.caPath);
          "tls crlfile" = mkIf (cfg.tls.crlPath != null) (mkOptionDefault cfg.tls.crlPath);
        })
        (mkIf cfg.usershare.enable {
          "usershare allow guests" = mkOptionDefault true;
          "usershare max shares" = mkOptionDefault 16;
          "usershare owner only" = mkOptionDefault true;
          "usershare template share" = mkOptionDefault cfg.usershare.templateShare;
          "usershare path" = mkOptionDefault cfg.usershare.path;
          "usershare prefix allow list" = mkOptionDefault [ cfg.usershare.path ];
        })
        (mkIf cfg.guest.enable {
          "map to guest" = mkOptionDefault "Bad User";
          "guest account" = mkOptionDefault cfg.guest.user;
        })
      ] ++ mapAttrsToList (_: idmap: mapAttrs' (key: value: nameValuePair "idmap config ${idmap.domain} : ${key}" (mkOptionDefault value)) idmap.settings) cfg.idmap.domains);
      extraConfig = mkMerge (
        mapAttrsToList (key: value: ''${key} = ${settingValue value}'') cfg.settings
        ++ [
          (mkIf (cfg.ldap.enable && cfg.ldap.passdb.enable) (mkBefore ''
            passdb backend = ${cfg.ldap.passdb.backend}:"${cfg.ldap.url}"
          ''))
        ]
      );
      shares.${cfg.usershare.templateShare} = mkIf cfg.usershare.enable {
        "-valid" = false;
      };
    };
    services.samba-wsdd = {
      workgroup = mkIf (cfg.domain.name != null && cfg.domain.isWorkgroup) (mkAlmostOptionDefault (toUpper cfg.domain.name));
      domain = mkIf (cfg.domain.name != null && !cfg.domain.isWorkgroup) (mkAlmostOptionDefault cfg.domain.name);
      hostname = mkIf (cfg.domain.netbiosName != null) (mkAlmostOptionDefault cfg.domain.netbiosName');
    };

    systemd.services.samba-smbd = mkIf cfg.enable {
      serviceConfig = let
        ldap-pass = pkgs.writeShellScript "samba-ldap-pass" ''
          ${cfg.package}/bin/smbpasswd -c /etc/samba/smb.conf -w $(cat ${cfg.ldap.adminPasswordPath})
        '';
      in {
        ExecStartPre = mkMerge [
          (mkIf (cfg.ldap.enable && cfg.ldap.adminPasswordPath != null) [
            "${ldap-pass}"
          ])
        ];
      };
    };

    systemd.tmpfiles.rules = mkIf (cfg.enable && cfg.usershare.enable) [
      "d ${cfg.usershare.path} 1770 root ${cfg.usershare.group}"
    ];

    networking.hosts = mkIf (cfg.enable && cfg.domain.netbiosName != null) {
      "::1" = mkAfter [ cfg.domain.netbiosName' ];
      # not a typo...
      "127.0.0.2" = mkAfter [ cfg.domain.netbiosName' ];
    };
    environment.etc."samba/lmhosts" = mkIf (cfg.enable && cfg.domain.lmhosts != { }) {
      text = mkMerge (
        mapAttrsToList (address: name: "${address} ${name}") cfg.domain.lmhosts
      );
    };

    networking.firewall.interfaces.local = {
      allowedTCPPorts = mkMerge [
        (mkIf (cfg.enable && !cfg.openFirewall) [139 445])
        (mkIf (samba-wsdd.enable && !samba-wsdd.openFirewall) [5357])
      ];
      allowedUDPPorts = mkMerge [
        (mkIf (cfg.enable && !cfg.openFirewall) [137 138])
        (mkIf (samba-wsdd.enable && !samba-wsdd.openFirewall) [3702])
      ];
    };
  };
}
