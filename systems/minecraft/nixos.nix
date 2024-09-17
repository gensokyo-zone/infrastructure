{meta, pkgs, ...}:{
  imports = let
    inherit (meta) nixos;
  in [
    nixos.sops
    nixos.reisen-ct
    nixos.tailscale
  ];

  environment.systemPackages = with pkgs; [
    jre
    tmux
  ];

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 25565 ];
  networking.firewall.interfaces.local.allowedTCPPorts = [ 25565 ];

  sops = {
    defaultSopsFile = ./secrets.yaml;
    secrets.tailscale-key.key = "tailscale-key";
  };

  system.stateVersion = "23.11";
}
