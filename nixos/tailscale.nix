{
  config,
  systemConfig,
  gensokyo-zone,
  lib,
  pkgs,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkDefault;
  inherit (lib.lists) elem;
  inherit (lib.strings) optionalString;
  inherit (lib.meta) getExe;
  cfg = config.services.tailscale;
in {
  options.services.tailscale = with lib.types; {
    advertiseExitNode = mkEnableOption "exit node";
  };
  config = {
    networking.firewall = {
      trustedInterfaces = [cfg.interfaceName];
      allowedUDPPorts = [cfg.port];
    };
    systemd.network = {
      wait-online.ignoredInterfaces = [cfg.interfaceName];
      networks."50-tailscale" = {
        networkConfig = {
          DNSDefaultRoute = false;
          #DNS = "";
        };
      };
    };

    services.tailscale.enable = mkDefault true;

    sops.secrets.tailscale-key = let
      keyNode = "tailscale-key-${systemConfig.proxmox.node.name}";
      keyGenso = "tailscale-key-gensokyo";
      # TODO: populate via lib.generate.nodeNames or something
      sharedKeys = [keyGenso "tailscale-key-reisen" "tailscale-key-meiling"];
    in
      mkIf cfg.enable {
        key = mkMerge [
          (mkIf systemConfig.proxmox.enabled (mkDefault keyNode))
          (mkIf (config.networking.domain == gensokyo-zone.lib.domain) (mkAlmostOptionDefault keyGenso))
        ];
        sopsFile = mkIf (elem config.sops.secrets.tailscale-key.key sharedKeys) (
          mkDefault ./secrets/tailscale.yaml
        );
      };
    systemd.services.tailscale-autoconnect = mkIf cfg.enable rec {
      description = "Automatic connection to Tailscale";

      # make sure tailscale is running before trying to connect to tailscale
      after = wants ++ wantedBy;
      wants = ["network-pre.target"];
      wantedBy = ["tailscaled.service"];

      # set this service as a oneshot job
      serviceConfig = {
        Type = "oneshot";
      };

      # have the job run this shell script
      script = let
        fixResolved = optionalString config.services.resolved.enable ''
          resolvectl revert ${cfg.interfaceName} || true
        '';
        # https://tailscale.com/kb/1320/performance-best-practices#ethtool-configuration
        exitNodeRouting = optionalString cfg.advertiseExitNode ''
          netdev=$(${pkgs.iproute2}/bin/ip route show 0/0 | ${pkgs.coreutils}/bin/cut -f5 -d' ' || echo ${config.systemd.network.networks._00-local.name or "eth0"})
          ${getExe pkgs.ethtool} -K "$netdev" rx-udp-gro-forwarding on rx-gro-list off || true
        '';
        advertiseExitNode = "--advertise-exit-node" + optionalString (!cfg.advertiseExitNode) "=false";
      in
        with pkgs; ''
          # wait for tailscaled to settle
          sleep 5

          ${fixResolved}
          ${exitNodeRouting}

          # check if we are already authenticated to tailscale
          status="$(${getExe tailscale} status -json | ${getExe jq} -r .BackendState)"
          if [[ $status = Running ]]; then
            # if so, then do nothing
            exit 0
          fi

          # otherwise authenticate with tailscale
          ${getExe tailscale} up --accept-dns=false ${advertiseExitNode} -authkey $(cat ${config.sops.secrets.tailscale-key.path})
        '';
    };
  };
}
