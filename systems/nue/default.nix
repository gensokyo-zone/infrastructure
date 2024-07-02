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
      address4 = "10.1.1.62";
      address6 = "fd0a::daf8:83ff:fe36:81b6";
    };
    tail = {
      imports = [netname];
      address4 = "100.86.77.54";
      address6 = "fd7a:115c:a1e0:ab12:4843:cd96:6256:4d36";
    };
  };
  exports.services = {
    sshd = {
      enable = true;
      ports.public.port = 62022;
    };
  };
}
