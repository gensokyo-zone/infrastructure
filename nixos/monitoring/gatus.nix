{ config, ... }: {
  sops.secrets.gatus_environment_file = {
    sopsFile = ../secrets/gatus.yaml;
  };
  services.gatus = {
    enable = true;
    environmentFile = config.sops.secrets.gatus_environment_file.path;
    settings = let
        # Common interval for refreshing all basic HTTP endpoints
        gatusCommonHTTPInterval = "30s";

        # Shared between all endpoints
        commonAlertingConfig = {
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
        # Used wherever a basic HTTP 200 up-check is required.
        basicHTTPCheck = url: {
            inherit url;
            interval = gatusCommonHTTPInterval;
            conditions = [
                "[STATUS] == 200"
            ];
         };
     in {
        # Environment variables are pulled in to be usable within the config.
        alerting.discord = {
            webhook-url = "\${DISCORD_WEBHOOK_URL}";
        };

        # Endpoint configuration
        endpoints = {
            # Home Assistant uses the common alerting config, combined with a basic HTTP check for its domain.
            "Home Assistant" = commonAlertingConfig // (basicHTTPCheck "https://home.local.gensokyo.zone");
        };

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
          address = "10.1.1.38";
          port = 9095;
        };

    };
  };

/*  services.nginx.virtualHosts."status.gensokyo.zone" = let
    gatusWebCfg = config.services.gatus.settings.web;
    upstream = "${gatusWebCfg.address}:${toString gatusWebCfg.port}";
  in {
    forceSSL = true;
    useACMEHost = serverName;
    kTLS = true;
    locations."/" = {
      proxyPass = "http://${upstream}";
      proxyWebsockets = true;
    };
  }; */

  networking.firewall.interfaces.local.allowedTCPPorts = [
    config.services.gatus.settings.web.port
  ];
}
