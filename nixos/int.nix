{
  lib,
  access,
  systemConfig,
  ...
}: let
  inherit (lib.modules) mkDefault;
in {
  config = {
    systemd.network.networks._00-int = {config, ...}: {
      networkConfig = {
        IPv6SendRA = mkDefault true;
      };
      ipv6SendRAConfig = {
        Managed = mkDefault false;
        EmitDNS = mkDefault true;
        DNS = [(access.systemForService "dnsmasq").access.address6ForNetwork.int];
        # Domains = [ "int.${networking.domain}" ];
        EmitDomains = mkDefault false;
        RouterPreference = mkDefault "low";
        RouterLifetimeSec = 0;
      };
      ipv6Prefixes = [
        {
          Prefix = "${systemConfig.network.networks.int.slaac.prefix}:/64";
          Assign = true;
          Token = config.ipv6AcceptRAConfig.Token;
        }
      ];
    };
  };
}
