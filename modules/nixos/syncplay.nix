{
  pkgs,
  config,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkMerge;
  cfg = config.services.syncplay;
  acme = config.security.acme.certs.${cfg.useACMECert};
  acmeDir = acme.directory;
in {
  options.services.syncplay = with lib.types; {
    openFirewall = mkOption {
      type = bool;
      default = false;
    };
    useACMECert = mkOption {
      type = nullOr str;
      default = null;
    };
  };

  config.services.syncplay = {
    certDir = let
      certDir = pkgs.linkFarm "syncplay-certs" [
        {
          name = "privkey.pem";
          path = "${acmeDir}/key.pem";
        }
        rec {
          name = "cert.pem";
          path = "${acmeDir}/${name}";
        }
        rec {
          name = "chain.pem";
          path = "${acmeDir}/${name}";
        }
      ];
    in
      mkIf (cfg.useACMECert != null) (mkAlmostOptionDefault certDir);
  };

  config.users = mkIf cfg.enable {
    users.syncplay = mkIf (cfg.user == "syncplay") {
      group = mkAlmostOptionDefault cfg.group;
      isSystemUser = true;
      home = mkAlmostOptionDefault "/var/lib/syncplay";
    };
    groups.syncplay =
      mkIf (cfg.group == "syncplay") {
      };
  };

  config.networking.firewall = mkIf cfg.enable {
    allowedTCPPorts = mkIf cfg.openFirewall [cfg.port];
  };

  config.systemd.services.syncplay = mkIf cfg.enable {
    wants = mkIf (cfg.useACMECert != null) ["acme-finished-${cfg.useACMECert}.target"];
    after = mkIf (cfg.useACMECert != null) ["acme-${cfg.useACMECert}.service"];
    confinement = {
      enable = mkAlmostOptionDefault true;
      packages = config.systemd.services.syncplay.path;
    };
    path = mkIf (cfg.passwordFile != null || cfg.saltFile != null) [pkgs.coreutils];
    serviceConfig = {
      StateDirectory = mkAlmostOptionDefault "syncplay";
      BindReadOnlyPaths = mkMerge [
        (mkIf (cfg.useACMECert != null) [
          "${acmeDir}"
        ])
        (mkIf (cfg.certDir != null) [
          "${cfg.certDir}"
        ])
      ];
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateMounts = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectControlGroups = true;
      ProtectProc = "invisible";
      RemoveIPC = true;
    };
  };
}
