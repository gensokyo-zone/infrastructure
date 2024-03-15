{
  inputs,
  lib,
  config,
  ...
}: let
  inherit (inputs.self.lib.lib) mkBaseDn;
  inherit (lib) mkIf mkMerge mkBefore mkDefault mkOptionDefault mkEnableOption mkOption;
  inherit (lib.strings) splitString concatMapStringsSep;
  inherit (config.lib.access) mkSnakeOil;
  cfg = config.services.kanidm;
in {
  options.services.kanidm = with lib.types; {
    server = {
      openFirewall = mkEnableOption "firewall ports";
      unencrypted = {
        enable = mkEnableOption "snake oil certificate";
        domain = mkOption {
          type = listOf str;
        };
        package = mkOption {
          type = package;
        };
      };
      frontend = {
        domain = mkOption {
          type = nullOr str;
          default = cfg.serverSettings.domain;
        };
        address = mkOption {
          type = str;
          default = "127.0.0.1";
        };
        port = mkOption {
          type = port;
          default = 8081;
        };
      };
      ldap = {
        enable = mkEnableOption "LDAP interface";
        address = mkOption {
          type = str;
          default = "127.0.0.1";
        };
        port = mkOption {
          type = port;
          default = 3636;
        };
        baseDn = mkOption {
          type = str;
          default = mkBaseDn cfg.serverSettings.domain;
        };
      };
    };
  };

  config = {
    networking.firewall.allowedTCPPorts = mkIf (cfg.enableServer && cfg.server.openFirewall) [
      cfg.server.frontend.port
      cfg.server.ldap.port
    ];

    services.kanidm = {
      server.unencrypted = {
        domain = mkBefore [cfg.server.frontend.domain];
        package = let
          cert = mkSnakeOil {
            name = "kanidm-cert";
            inherit (cfg.server.unencrypted) domain;
          };
        in
          mkOptionDefault cert;
      };
      clientSettings = mkIf cfg.enableServer {
        uri = mkDefault cfg.serverSettings.origin;
      };
      serverSettings = mkMerge [
        {
          domain = mkDefault config.networking.domain;
          origin = mkDefault "https://${cfg.server.frontend.domain}";
          bindaddress = mkDefault "${cfg.server.frontend.address}:${toString cfg.server.frontend.port}";
          ldapbindaddress = mkIf cfg.server.ldap.enable (
            mkDefault "${cfg.server.ldap.address}:${toString cfg.server.ldap.port}"
          );
        }
        (mkIf cfg.server.unencrypted.enable {
          tls_chain = "${cfg.server.unencrypted.package}/fullchain.pem";
          tls_key = "${cfg.server.unencrypted.package}/key.pem";
        })
      ];
    };
  };
}
