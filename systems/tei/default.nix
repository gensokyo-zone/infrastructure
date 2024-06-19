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
      nginx = {
        enable = true;
        ports.proxied.enable = true;
      };
      tailscale.enable = true;
      home-assistant.enable = true;
      zigbee2mqtt.enable = true;
      barcodebuddy.enable = true;
      postgresql.enable = true;
      adb.enable = true;
    };
  };
}
