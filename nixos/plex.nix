{...}: {
  services.plex.enable = true;

  # Plex Media Server:
  #
  # TCP:
  # * 32400 - direct HTTP access - we don't want to open this considering we're reverse proxying
  # * 8324 - Roku via Plex Companion
  # * 32469 - Plex DLNA Server
  # UDP:
  # * 1900 - DLNA
  # * 32410, 32412, 32413, 32414 - GDM Network Discovery

  networking.firewall.interfaces.local = {
    allowedTCPPorts = [32400 8324 32469];
    allowedUDPPorts = [1900 32410 32412 32413 32414];
  };
}
