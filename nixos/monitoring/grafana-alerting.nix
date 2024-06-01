{config, ...}: {
  sops.secrets.grafana_discord_webhook_url = {
    sopsFile = ../secrets/grafana.yaml;
    owner = "grafana";
  };
  services.grafana.provision.alerting.contactPoints.settings = {
    apiVersion = 1;
    contactPoints = [
      {
        orgId = 1;
        name = "Discord";
        receivers = [
          {
            uid = "discord_alerting";
            type = "discord";
            disableResolveMessage = false;
            settings = {
              url = "$__file{${config.sops.secrets.grafana_discord_webhook_url.path}}";
              #avatar_url = "";
            };
          }
        ];
      }
    ];
  };
}
