{
  meta,
  lib,
  ...
}: {
  imports = with meta; [
    nixos.reisen-ct
    nixos.sops
    nixos.tailscale
    nixos.nginx
    nixos.acme
    nixos.cloudflared

    /*
      # media
    nixos.plex
    nixos.tautuli
    nixos.ombi

    # yarr harr fiddle dee dee >w<
    nixos.radarr
    nixos.sonarr
    nixos.bazarr
    nixos.jackett
    */
  ];

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "21.05";
}
