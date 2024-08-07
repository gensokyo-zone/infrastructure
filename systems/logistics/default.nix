_: {
  arch = "x86_64";
  type = "NixOS";
  modules = [
    ./nixos.nix
  ];
  exports = {
    services = {
      motion = {
        id = "kitchen";
        enable = true;
        ports.stream.port = 41081;
      };
      octoprint.enable = true;
      nginx.enable = true;
      moonraker.enable = true;
      fluidd.enable = true;
    };
  };
  network.networks = {
    local = {
      slaac.postfix = "40c3:23df:e82a:b214";
      address4 = "10.1.1.63";
    };
  };
}
