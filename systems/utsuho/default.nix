_: {
  imports = [
    ./proxmox.nix
  ];
  arch = "x86_64";
  type = "NixOS";
  modules = [
    ./nixos.nix
  ];
  exports = {
    services = {
      sshd.enable = true;
      nginx.enable = true;
      unifi.enable = true;
      mosquitto.enable = true;
      dnsmasq.enable = true;
    };
  };
}
