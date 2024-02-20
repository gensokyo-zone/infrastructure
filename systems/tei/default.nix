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
      tailscale.enable = true;
      home-assistant.enable = true;
      zigbee2mqtt.enable = true;
      postgresql.enable = true;
    };
  };
}
