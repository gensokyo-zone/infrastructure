{ config, lib, pkgs, utils, ... }:

with lib;

let
  cfg = config.services.syncplay;
  args = [
    "--disable-ready"
    "--port" cfg.port
  ] ++ optionals (cfg.certDir != null) [ "--tls" cfg.certDir ];

in {
  sops.secrets.syncplay-env.owner = cfg.user;

  users.users.${cfg.user} = {
    inherit (cfg) group;
    isSystemUser = true;
    home = "/var/lib/syncplay";
  };
  users.groups.${cfg.group} = { };

  networks.internet.tcp = [ cfg.port ];

  domains.kittywitch-syncplay = {
    network = "internet";
    type = "cname";
    domain = "sync";
  };

  networks.internet = {
    extra_domains = [
      "sync.kittywit.ch"
    ];
  };

  services.syncplay = {
    enable = true;
    user = "syncplay";
  };
  systemd.services.syncplay = mkIf cfg.enable {
    serviceConfig = {
      StateDirectory = "syncplay";
      EnvironmentFile = singleton config.sops.secrets.syncplay-env.path;
      ExecStart = mkForce [
        "${pkgs.syncplay-nogui}/bin/syncplay-server ${utils.escapeSystemdExecArgs args}"
      ];
    };
  };
}
