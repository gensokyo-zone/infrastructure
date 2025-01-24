_: {
  imports = [
    ./proxmox.nix
  ];
  arch = "x86_64";
  type = "NixOS";
  modules = [
    ./nixos.nix
  ];
  network.networks = {
    tail = {
      address4 = "100.104.170.16";
      address6 = "fd7a:115c:a1e0::ee01:aa11";
    };
  };
  exports = let
    wyomingBroke = builtins.trace "WYOMING MODULE BROKE" false;
  in {
    services = {
      tailscale.enable = true;
      nginx = {
        enable = true;
        ports.proxied.enable = true;
      };
      piper.enable = wyomingBroke;
      faster-whisper.enable = wyomingBroke;
      openwakeword.enable = wyomingBroke;
      cloudflared.enable = true;
      plex.enable = true;
      invidious.enable = true;
      deluge.enable = true;
    };
  };
}
