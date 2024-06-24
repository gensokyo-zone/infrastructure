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
      keycloak.enable = true;
      vouch-proxy.enable = true;
      vaultwarden.enable = true;
      cloudflared.enable = true;
      nginx = {
        enable = true;
        ports.proxied.enable = true;
      };
    };
  };
}
