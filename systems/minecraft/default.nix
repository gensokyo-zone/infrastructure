_: {
  imports = [
    ./proxmox.nix
  ];
  arch = "x86_64";
  type = "NixOS";
  modules = [
    ./nixos.nix
  ];
  access.online = {
    # temporarily offline for server migration
    available = false;
  };
  exports = {
    services = {
      tailscale.enable = true;
      minecraft = {
        enable = true;
        id = "marka";
        ports = {
          query.enable = true;
          bluemap.enable = true;
        };
      };
    };
  };
}
