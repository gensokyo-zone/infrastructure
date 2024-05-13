{
  gensokyo-zone,
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault mapOptionDefaults mapAlmostOptionDefaults mapDefaults;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkAfter mkDefault mkOptionDefault;
  inherit (config.security) krb5 ipa;
  inherit (config.services) sssd;
  genso = krb5.gensokyo-zone;
  cfg = sssd.gensokyo-zone;
  serverModule = {config, ...}: {
    options = with lib.types; {
      servers = mkOption {
        type = nullOr (listOf str);
        default = null;
      };
      backups = mkOption {
        type = listOf str;
        default = [];
      };
      serverName = mkOption {
        type = str;
        internal = true;
      };
      serverKind = mkOption {
        type = enum ["server" "uri"];
        default = "server";
        internal = true;
      };
      settings = mkOption {
        type = attrsOf (listOf str);
      };
    };
    config = let
      key = "${config.serverName}_${config.serverKind}";
      keyBackups = "${config.serverName}_backup_${config.serverKind}";
    in {
      settings = {
        ${key} = mkIf (config.servers != null) (mkOptionDefault config.servers);
        ${keyBackups} = mkIf (config.backups != []) (mkOptionDefault config.backups);
      };
    };
  };
  mkServerType = {modules}:
    lib.types.submoduleWith {
      modules = [serverModule] ++ modules;
      specialArgs = {
        inherit gensokyo-zone pkgs;
        nixosConfig = config;
      };
    };
  mkServerOption = {
    name,
    kind ? "server",
  }: let
    serverInfoModule = {...}: {
      config = {
        serverName = mkOptionDefault name;
        serverKind = mkAlmostOptionDefault kind;
      };
    };
  in
    mkOption {
      type = mkServerType {
        modules = [serverInfoModule];
      };
      default = {};
    };
in {
  options.services.sssd.gensokyo-zone = with lib.types; {
    enable =
      mkEnableOption "realm"
      // {
        default = genso.enable;
      };
    ldap = {
      bind = {
        passwordFile = mkOption {
          type = nullOr str;
          default = null;
        };
      };
      uris = mkServerOption {
        name = "ldap";
        kind = "uri";
      };
    };
    krb5 = {
      servers = mkServerOption {name = "krb5";};
    };
    ipa = {
      servers =
        mkServerOption {name = "ipa";}
        // {
          default = {
            inherit (cfg.krb5.servers) servers backups;
          };
        };
      hostName = mkOption {
        type = str;
        default = config.networking.fqdn;
      };
    };
    backend = mkOption {
      type = enum ["ldap" "ipa"];
      default = "ipa";
    };
  };
  config = {
    services.sssd = let
      # or "ipaNTSecurityIdentifier" which isn't set for most groups, maybe check netgroups..?
      objectsid = "sambaSID";
      backendDomainSettings = {
        ldap =
          mapDefaults {
            id_provider = "ldap";
            auth_provider = "krb5";
            access_provider = "ldap";
            ldap_tls_cacert = "/etc/ssl/certs/ca-bundle.crt";
          }
          // mapOptionDefaults {
            ldap_access_order = ["host"];
            ldap_schema = "IPA";
            ldap_default_bind_dn = genso.ldap.bind.dn;
            ldap_search_base = genso.ldap.baseDn;
            ldap_user_search_base = "cn=users,cn=accounts,${genso.ldap.baseDn}";
            ldap_group_search_base = "cn=groups,cn=accounts,${genso.ldap.baseDn}";
            ldap_user_uuid = "ipaUniqueID";
            ldap_user_ssh_public_key = "ipaSshPubKey";
            ldap_user_objectsid = objectsid;
            ldap_group_uuid = "ipaUniqueID";
            ldap_group_objectsid = objectsid;
          };
        ipa = mapOptionDefaults {
          id_provider = "ipa";
          auth_provider = "ipa";
          access_provider = "ipa";
          chpass_provider = "ipa";
          dyndns_update = ipa.dyndns.enable;
          dyndns_iface = ipa.dyndns.interface;
        };
      };
      domainSettings =
        mapAlmostOptionDefaults {
          ipa_hostname = cfg.ipa.hostName;
        }
        // mapOptionDefaults {
          enumerate = true;
          ipa_domain = genso.domain;
          krb5_realm = genso.realm;
          cache_credentials = ipa.cacheCredentials;
          krb5_store_password_if_offline = ipa.offlinePasswords;
          #min_id = 8000;
          #max_id = 8999;
        };
    in {
      gensokyo-zone = {
        krb5.servers.servers = mkMerge [
          [genso.host]
          (mkAfter ["_srv" genso.canonHost])
        ];
        ldap.uris = {
          servers = mkMerge [
            (mkAfter ["_srv"])
            genso.ldap.urls
          ];
        };
      };
      domains = mkIf cfg.enable {
        ${genso.domain} = {
          ldap = {
            authtok = mkIf (cfg.backend == "ldap") {
              passwordFile = mkIf (cfg.ldap.bind.passwordFile != null) (mkAlmostOptionDefault cfg.ldap.bind.passwordFile);
            };
            extraAttrs.user = {
              mail = "mail";
              sn = "sn";
              givenname = "givenname";
              telephoneNumber = "telephoneNumber";
              lock = "nsaccountlock";
            };
          };
          settings = mkMerge [
            domainSettings
            backendDomainSettings.${cfg.backend}
            (mapAlmostOptionDefaults cfg.ldap.uris.settings)
            (mapAlmostOptionDefaults cfg.krb5.servers.settings)
            (mkIf (cfg.backend == "ipa") (mapAlmostOptionDefaults cfg.ipa.servers.settings))
          ];
        };
      };
      services = mkIf cfg.enable {
        nss.settings = mapOptionDefaults {
          homedir_substring = "/home";
        };
        pam.settings = mapOptionDefaults {
          pam_pwd_expiration_warning = 3;
          pam_verbosity = 3;
        };
        sudo.enable = mkIf (!sssd.services.pam.enable) (mkDefault false);
        ssh.enable = mkIf (!sssd.services.pam.enable) (mkDefault false);
        ifp = {
          enable = mkAlmostOptionDefault true;
          settings = mapOptionDefaults {
            allowed_uids = ipa.ifpAllowedUids;
          };
        };
      };
    };
  };
}
