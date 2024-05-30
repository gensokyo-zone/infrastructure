_: {
  arch = "x86_64";
  type = "NixOS";
  modules = [
    ./nixos.nix
  ];
  ci.allowFailure = true;
  proxmox = {
    vm = {
      id = 201;
      enable = true;
    };
    network.interfaces = {
      net0 = {
        mdns.enable = false;
        name = "ens18";
        macAddress = "BC:24:11:49:FE:DC";
        address4 = "10.1.1.42/24";
        address6 = "auto";
      };
    };
  };
  exports = {
    services = {
    };
  };
}
