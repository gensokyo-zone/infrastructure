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
      unifi.enable = true;
      mosquitto.enable = true;
      dnsmasq.enable = true;
      grafana.enable = true;
      loki.enable = true;
      prometheus.enable = true;
      gatus.enable = true;
    };
  };
}
