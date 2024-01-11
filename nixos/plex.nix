_: {
  services = {
    plex = {
      enable = true;
    };
    nginx.virtualHosts."plex.gensokyo.zone" = {
      enableACME = true;
      locations."/".proxyPass = "http://localhost:32400";
    };
  };

  # Plex Media Server:
  #
  # TCP:
  # * 32400 - direct HTTP access - we don't want to open this considering we're reverse proxying
  # * 8324 - Roku via Plex Companion
  # * 32469 - Plex DLNA Server
  # UDP:
  # * 1900 - DLNA
  # * 5353 - Bonjour / Avahi
  # * 32410, 32412, 32413, 32414 - GDM Network Discovery

  # Tautulli and Ombi will also be reverse proxied, presumably

  networking.firewall = {
    allowedTCPPorts = [8324 32469];
    allowedUDPPorts = [1900 5353 32410 32412 32413 32414];
  };
}
