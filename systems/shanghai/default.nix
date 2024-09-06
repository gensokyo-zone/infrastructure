{
  config,
  lib,
  ...
}: let
  inherit (lib.strings) concatStringsSep;
  dot = concatStringsSep ".";
  cutie = dot ["cutie" "moe"];
  netname = {config, ...}: {
    domain = dot [config.name cutie];
  };
in {
  type = "Linux";
  access = {
    domain = dot ["gensokyo" cutie];
    fqdnAliases = map dot [
      [config.access.hostName cutie]
      #[config.access.hostName gensokyo-zone.lib.domain]
    ];
  };
  network.networks = {
    local = {
      imports = [netname];
      macAddress = let
        #eth = "18:c0:4d:08:87:bd";
        eth25 = "18:c0:4d:08:87:bc";
      in
        eth25;
      address4 = "10.1.1.32";
    };
    tail = {
      imports = [netname];
      address4 = "100.107.45.44";
      address6 = "fd7a:115c:a1e0::4e01:2d2c";
    };
  };
  exports.services = {
    #tailscale.enable = true;
    sshd = {
      enable = true;
      ports.public.port = 32022;
    };
    prometheus-exporters-node.enable = true;
  };
}
