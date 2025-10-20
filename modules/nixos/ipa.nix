{
  pkgs,
  config,
  lib,
  gensokyo-zone,
  modulesPath,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault mkAlmostForce mapOptionDefaults;
  inherit (lib.options) mkOption mkPackageOption;
  inherit (lib.modules) mkIf mkMerge mkOptionDefault mkForce;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.strings) toLower;
  cfg = config.security.ipa;
in {
  options.security.ipa = with lib.types; {
    package = mkPackageOption pkgs "freeipa" {};
    overrideConfigs = {
      krb5 = mkOption {
        type = bool;
        default = true;
        description = "allow the ipa module to override krb5.conf";
      };
      sssd = mkOption {
        type = bool;
        default = true;
        description = "allow the ipa module to override the sssd configuration";
      };
      ntp = mkOption {
        type = bool;
        default = false;
        description = "allow the ipa module to override the ntp configuration";
      };
      openldap = mkOption {
        type = bool;
        default = false;
        description = "allow the ipa module to override ldap.conf";
      };
    };
    openldap = {
      settings = {
        uri = mkOption {
          type = str;
          default = "ldaps://${cfg.server}";
        };
        base = mkOption {
          type = str;
          default = cfg.basedn;
        };
        tls_cacert = mkOption {
          type = str;
          default = "/etc/ipa/ca.crt";
        };
        sasl_nocanon = mkOption {
          type = bool;
          default = true;
        };
      };
      extraConfig = mkOption {
        type = lines;
        default = ''
          SASL_NOCANON ${if cfg.openldap.settings.sasl_nocanon or false then "on" else "off"}
          URI ${cfg.openldap.settings.uri}
          BASE ${cfg.openldap.settings.base}
          TLS_CACERT ${cfg.openldap.settings.tls_cacert}
        '';
      };
    };
  };
  config.services.sssd = let
    inherit (config.services) sssd;
    ipaDebugLevel = 65510;
  in
    mkIf cfg.enable {
      debugLevel = mkAlmostOptionDefault ipaDebugLevel;
      domains = {
        ${cfg.domain} = {
          ldap.extraAttrs.user = {
            mail = "mail";
            sn = "sn";
            givenname = "givenname";
            telephoneNumber = "telephoneNumber";
            lock = "nsaccountlock";
          };
          settings =
            mapOptionDefaults {
              id_provider = "ipa";
              auth_provider = "ipa";
              access_provider = "ipa";
              chpass_provider = "ipa";
              ipa_domain = cfg.domain;

              ipa_server = ["_srv_" cfg.server];

              ipa_hostname = "${config.networking.hostName}.${cfg.domain}";

              cache_credentials = cfg.cacheCredentials;

              krb5_store_password_if_offline = cfg.offlinePasswords;

              dyndns_update = cfg.dyndns.enable;

              dyndns_iface = cfg.dyndns.interface;

              ldap_tls_cacert = "/etc/ipa/ca.crt";
            }
            // {
              krb5_realm = mkIf (toLower cfg.domain != toLower cfg.realm) (mkOptionDefault cfg.realm);
            };
        };
      };
      services = {
        nss.settings = mapOptionDefaults {
          homedir_substring = "/home";
        };
        pam.settings = mapOptionDefaults {
          pam_pwd_expiration_warning = 3;
          pam_verbosity = 3;
        };
        sudo = {
          enable = mkAlmostOptionDefault true;
          settings = mapOptionDefaults {
            debug_level = ipaDebugLevel;
          };
        };
        ssh.enable = mkAlmostOptionDefault true;
        ifp = {
          enable = mkAlmostOptionDefault true;
          settings = mapOptionDefaults {
            allowed_uids = cfg.ifpAllowedUids;
          };
        };
      };
      configText = mkIf (cfg.overrideConfigs.sssd) (mkAlmostOptionDefault null);
      config = mkIf (sssd.configText != null) (mkAlmostForce sssd.configText);
    };
  config.security.krb5 = mkIf cfg.enable {
    enable = mkAlmostForce false;
    package = mkAlmostOptionDefault pkgs.krb5Full;
    settings = {
      libdefaults = mapOptionDefaults {
        default_realm = cfg.realm;
        dns_lookup_realm = false;
        dns_lookup_kdc = true;
        rdns = false;
        ticket_lifetime = "24h";
        forwardable = true;
        udp_preference_limit = 0;
      };
      realms.${cfg.realm} = mapOptionDefaults {
        kdc = "${cfg.server}:88";
        master_kdc = "${cfg.server}:88";
        admin_server = "${cfg.server}:749";
        default_domain = cfg.domain;
        pkinit_anchors = "/etc/ipa/ca.crt";
      };
      domain_realm = mkMerge [
        (mapOptionDefaults {
          ".${cfg.domain}" = cfg.realm;
          ${cfg.domain} = cfg.realm;
        })
        (mapOptionDefaults {
          ${cfg.server} = cfg.realm;
        })
      ];
      dbmodules.${cfg.realm} = {
        db_library = "${cfg.package}/lib/krb5/plugins/kdb/ipadb.so";
      };
    };
  };
  config.services.ntp = mkIf (cfg.enable && !cfg.overrideConfigs.ntp) {
    servers = mkForce config.networking.timeServers;
  };
  config.environment.etc."krb5.conf" = let
    inherit (config.security) krb5;
    format = import (modulesPath + "/security/krb5/krb5-conf-format.nix") {inherit pkgs lib;} {};
  in
    mkIf (cfg.enable && !cfg.overrideConfigs.krb5) {
      text = mkForce (format.generate "krb5.conf" krb5.settings).text;
    };
  config.environment.etc."ldap.conf" = let
    ldapConf = cfg.openldap.extraConfig;
  in
    mkIf (cfg.enable && !cfg.overrideConfigs.openldap) {
      source = mkForce (pkgs.writeText "ldap.conf" ldapConf);
    };
}
