{lib, ...}: let
  inherit (lib.strings) concatStringsSep;
  dot = concatStringsSep ".";
  cutie = dot ["cutie" "moe"];
  netname = {config, ...}: {
    domain = dot [config.name cutie];
  };
in {
  type = "Linux";
  access.domain = dot ["gensokyo" cutie];
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
      address4 = "100.104.155.122";
      address6 = "fd7a:115c:a1e0:ab12:4843:cd96:6268:9b7a";
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
