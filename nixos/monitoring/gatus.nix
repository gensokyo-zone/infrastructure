{
  config,
  access,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (gensokyo-zone) systems;
  inherit (gensokyo-zone.lib) mkAddress6 mkAlmostOptionDefault mapOptionDefaults unmerged;
  inherit (lib.modules) mkIf mkMerge mkDefault mkOptionDefault;
  inherit (lib.attrsets) attrValues nameValuePair listToAttrs;
  inherit (lib.lists) filter length optional concatMap;
  inherit (lib.strings) hasPrefix hasInfix optionalString concatStringsSep match;
  cfg = config.services.gatus;
  statusSystems = filter (system: system.config.exports.status.enable) (attrValues systems);
  mapSystem = system: let
    statusServices = map (serviceName: system.config.exports.services.${serviceName}) system.config.exports.status.services;
    serviceEndpoints = concatMap (mkServiceEndpoint system) statusServices;
    systemEndpoint = mkSystemEndpoint system;
  in
    serviceEndpoints ++ [systemEndpoint];
  mkPortEndpoint = {
    system,
    service,
    port,
    unique,
  }: let
    inherit (port.status) gatus;
    hasId = service.id != service.name;
    displayName = service.displayName + optionalString (!unique && port.displayName != null) "/${port.displayName}";
    name = concatStringsSep "-" ([
        service.name
      ]
      ++ optional hasId service.id
      ++ [
        port.name
        system.config.name
      ]);
    #network = port.listen;
    network = "lan";
    protocolOverrides = {
      dns = {
        # XXX: they're lying when they say "You may optionally prefix said DNS IPs with dns://"
        scheme = "";
      };
      starttls.host = system.config.access.fqdn;
    };
    urlConf =
      {
        inherit service port network;
        system = system.config;
        scheme = gatus.protocol;
        ${
          if gatus.client.network != "ip"
          then "getAddressFor"
          else null
        } =
          {
            ip = "getAddressFor";
            ip4 = "getAddress4For";
            ip6 = "getAddress6For";
          }
          .${gatus.client.network};
      }
      // protocolOverrides.${gatus.protocol} or {};
    url = access.proxyUrlFor urlConf + optionalString (gatus.http.path != "/") gatus.http.path;
    conf = {
      enabled = mkIf (gatus.protocol == "starttls") (mkAlmostOptionDefault false);
      name = mkAlmostOptionDefault displayName;
      group = mkAlmostOptionDefault groups.services;
      url = mkOptionDefault url;
      client.network = mkAlmostOptionDefault gatus.client.network;
    };
  in
    nameValuePair name (_: {
      imports =
        [alertingConfig]
        ++ optional port.status.alert.enable alertingConfigAlerts
        ++ optional (gatus.protocol == "http" || gatus.protocol == "https") alertingConfigHttp;

      config = mkMerge [
        (unmerged.mergeAttrs gatus.settings)
        conf
      ];
    });
  mkServiceEndpoint = system: service: let
    statusPorts =
      map
      (portName: service.ports.${portName})
      service.status.ports;
    gatusPorts = filter (port: port.status.gatus.enable) statusPorts;
    unique = length gatusPorts == 1;
  in
    map (port:
      mkPortEndpoint {
        inherit system service port unique;
      })
    gatusPorts;
  mkSystemEndpoint = system: let
    inherit (system.config.exports) status;
    network = "lan";
    getAddressFor =
      if system.config.network.networks.local.address4 or null != null
      then "getAddress4For"
      else "getAddressFor";
    addr = access.${getAddressFor} system.config.name network;
    addrIs6 = hasInfix ":" addr;
  in
    nameValuePair "ping-${system.config.name}" (_: {
      imports =
        [alertingConfig]
        ++ optional status.alert.enable alertingConfigAlerts;
      config = {
        name = mkAlmostOptionDefault system.config.name;
        # XXX: it can't seem to ping ipv6 for some reason..? :<
        enabled = mkIf addrIs6 (mkAlmostOptionDefault false);
        client.network = mkIf addrIs6 (mkAlmostOptionDefault "ip6");
        group = mkAlmostOptionDefault (groups.forSystem system);
        url = mkOptionDefault "icmp://${mkAddress6 addr}";
      };
    });
  alertingConfigAlerts = {
    alerts = [
      {
        type = "discord";
        send-on-resolved = true;
        description = "Healthcheck failed.";
        failure-threshold = 10;
        success-threshold = 3;
      }
    ];
  };
  alertingConfigHttp = {
    # Common interval for refreshing all basic HTTP endpoints
    interval = mkAlmostOptionDefault "30s";
  };
  alertingConfig = {config, ...}: let
    isLan = match ''.*(::|10\.|127\.|\.(local|int|tail)\.).*'' config.url != null;
    isDns = hasPrefix "dns://" config.url || config.dns.query-name or null != null;
  in {
    conditions = mkOptionDefault [
      "[CONNECTED] == true"
    ];
    ui = mkMerge [
      (mkIf isDns {
        hide-conditions = mkAlmostOptionDefault true;
      })
      (mkIf isLan {
        hide-hostname = mkAlmostOptionDefault true;
        hide-url = mkAlmostOptionDefault true;
      })
    ];
    client = {
      # XXX: no way to specify SSL hostname/SNI separately from the url :<
      insecure = mkAlmostOptionDefault true;
    };
  };
  groups = {
    services = "Services";
    servers = "${groups.systems}/Servers";
    systems = "Systems";
    forSystem = system: let
      node = systems.${system.config.proxmox.node.name}.config;
    in
      if system.config.proxmox.enabled
      then "${groups.servers}/${node.name}"
      else if system.config.access.online.available
      then groups.servers
      else groups.systems;
  };
in {
  sops.secrets.gatus_environment_file = mkIf cfg.enable {
    sopsFile = mkDefault ../secrets/gatus.yaml;
    owner = cfg.user;
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

  networking.firewall.interfaces.lan.allowedTCPPorts = mkIf cfg.enable [
    cfg.settings.web.port
  ];
}
