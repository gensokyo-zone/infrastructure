{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (lib) mkIf mkMerge mkDefault mkOptionDefault mkEnableOption mkOption;
  cfg = config.services.kanidm;
in {
  options.services.kanidm = with lib.types; {
    server = {
      openFirewall = mkEnableOption "firewall ports";
      unencrypted = {
        enable = mkEnableOption "snake oil certificate";
        domain = mkOption {
          type = str;
          default = cfg.server.frontend.domain;
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
          default = 636;
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
      server.unencrypted.package = let
        cert = pkgs.runCommand "kanidm-cert" {
          inherit (cfg.server.unencrypted) domain;
          nativeBuildInputs = [ pkgs.buildPackages.minica ];
        } ''
          install -d $out
          cd $out
          minica \
            --ca-key ca.key.pem \
            --ca-cert ca.cert.pem \
            --domains $domain
          cat $domain/cert.pem ca.cert.pem > $domain.pem
        '';
      in mkOptionDefault cert;
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
          tls_chain = "${cfg.server.unencrypted.package}/${cfg.server.unencrypted.domain}.pem";
          tls_key = "${cfg.server.unencrypted.package}/${cfg.server.unencrypted.domain}/key.pem";
        })
      ];
    };
  };
}
