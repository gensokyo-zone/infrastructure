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
      minecraft-bedrock-server.enable = true;
    };
  };
}
