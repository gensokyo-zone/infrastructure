{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  options.deploy.system = mkOption {
    type = types.unspecified;
    readOnly = true;
  };
  config = {
    deploy.system = config.system.build.toplevel;

    networking.domain = "inskip.me";

    networking.firewall = {
      trustedInterfaces = [config.services.tailscale.interfaceName];
      allowedUDPPorts = [config.services.tailscale.port];
    };
    systemd.network = {
      wait-online.ignoredInterfaces = [config.services.tailscale.interfaceName];
      networks."50-tailscale" = {
        networkConfig = {
          DNSDefaultRoute = false;
        };
      };
    };

    services.tailscale.enable = true;

    sops.secrets.tailscale-key = { };
    systemd.services.tailscale-autoconnect = mkIf config.services.tailscale.enable rec {
      description = "Automatic connection to Tailscale";

      # make sure tailscale is running before trying to connect to tailscale
      after = wants ++ wantedBy;
      wants = [ "network-pre.target" ];
      wantedBy = [ "tailscaled.service" ];

      # set this service as a oneshot job
      serviceConfig = {
        Type = "oneshot";
      };

      # have the job run this shell script
      script = with pkgs; ''
        # wait for tailscaled to settle
        sleep 5

        resolvectl revert ${config.services.tailscale.interfaceName} || false

        # check if we are already authenticated to tailscale
        status="$(${getExe tailscale} status -json | ${getExe jq} -r .BackendState)"
        if [[ $status = Running ]]; then
          # if so, then do nothing
          exit 0
        fi

        # otherwise authenticate with tailscale
        ${getExe tailscale} up --advertise-exit-node -authkey $(cat ${config.sops.secrets.tailscale-key.path})
      '';
    };
  };
}
