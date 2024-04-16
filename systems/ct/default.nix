_: {
  arch = "x86_64";
  type = "NixOS";
  modules = [
    ./nixos.nix
  ];
  access.online.enable = false;
  network.networks = {
    local = {
      fqdn = null;
      address4 = null;
      address6 = null;
    };
  };
  exports = {
    services = {
      sshd.enable = true;
    };
  };
}
