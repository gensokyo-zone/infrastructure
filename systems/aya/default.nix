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
      minecraft-bedrock-server.enable = true;
    };
  };
}
