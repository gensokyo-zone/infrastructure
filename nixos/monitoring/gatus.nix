{
  config,
  access,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (gensokyo-zone) systems;
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault unmerged;
  inherit (lib.modules) mkMerge mkOptionDefault;
  inherit (lib.attrsets) attrValues nameValuePair listToAttrs;
  inherit (lib.lists) filter length optional concatMap;
  cfg = config.services.gatus;
  statusSystems = filter (system: system.config.access.online.enable) (attrValues systems);
  mapSystem = system: let
    statusServices = map (serviceName: system.config.exports.services.${serviceName}) system.config.exports.status.services;
  in concatMap (mkServiceEndpoint system) statusServices;
  mkPortEndpoint = { system, service, port, unique }: let
    inherit (port.status) gatus;
    name = if unique
      then service.displayName
      else "${service.displayName}: ${port.name}";
    conf = {
      url = mkOptionDefault (access.proxyUrlFor {
        inherit service port;
        system = system.config;
        scheme = gatus.protocol;
        #network = port.listen;
      });
    };
  in nameValuePair name ({ ... }: {
    imports =
      optional port.status.alert.enable alertingConfigAlerts
      ++ optional (gatus.protocol == "http" || gatus.protocol == "https") alertingConfigHttp;

    config = mkMerge [
      (unmerged.mergeAttrs gatus.settings)
      conf
    ];
  });
  mkServiceEndpoint = system: service: let
    statusPorts = map /*lib.attrsets.getAttr*/(portName: service.ports.${portName}) service.status.ports;
    gatusPorts = filter (port: port.status.gatus.enable) statusPorts;
    unique = length gatusPorts == 1;
  in map (port: mkPortEndpoint {
    inherit system service port unique;
  }) gatusPorts;
  alertingConfigAlerts = {
    alerts = [
      {
        type = "discord";
        send-on-resolved = true;
        description = "Healthcheck failed.";
        failure-threshold = 1;
        success-threshold = 3;
      }
    ];
  };
  alertingConfigHttp = {
    # Common interval for refreshing all basic HTTP endpoints
    interval = mkAlmostOptionDefault "30s";
  };
in {
  sops.secrets.gatus_environment_file = {
    sopsFile = ../secrets/gatus.yaml;
  };
  services.gatus = {
    enable = true;
    environmentFile = config.sops.secrets.gatus_environment_file.path;
    settings = {
      # Environment variables are pulled in to be usable within the config.
      alerting.discord = {
        webhook-url = "\${DISCORD_WEBHOOK_URL}";
      };

      # Endpoint configuration
      endpoints = listToAttrs (concatMap mapSystem statusSystems);

      # The actual status page configuration
      ui = {
        title = "Gensokyo Zone Status";
        description = "The status of the various girls in Gensokyo!";
        header = "Gensokyo Zone Status";
      };

      # Prometheus metrics...!
      metrics = true;

      # We could've used Postgres, but it seems like less moving parts if our status page
      # doesn't depend upon another service, internal or external, other than what gets it to the internet.
      storage = {
        type = "sqlite";
        path = "/var/lib/gatus/data.db";
      };

      # Bind on the local address for now, on the port after the last one allocated for the monitoring project.
      web = {
        address = "[::]";
        port = 9095;
      };
    };
  };

  networking.firewall.interfaces.lan.allowedTCPPorts = [
    cfg.settings.web.port
  ];
}
