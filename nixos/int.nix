{config, lib, access, ...}: let
  inherit (lib.modules) mkDefault;
in {
  config = {
    systemd.network.networks.eth9 = {config, ...}: {
      networkConfig = {
        IPv6SendRA = mkDefault true;
      };
      ipv6SendRAConfig = {
        Managed = mkDefault false;
        EmitDNS = mkDefault true;
        DNS = [ (access.getAddress6For "utsuho" "int") ];
        # Domains = [ "int.${networking.domain}" ];
        EmitDomains = mkDefault false;
        RouterPreference = mkDefault "low";
        RouterLifetimeSec = 0;
      };
      ipv6Prefixes = [
        {
          ipv6PrefixConfig = {
            Prefix = "fd0c::/64";
            Assign = true;
            Token = config.ipv6AcceptRAConfig.Token;
          };
        }
      ];
    };
  };
}
