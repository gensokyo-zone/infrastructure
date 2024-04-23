{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  networking.firewall.interfaces.local.allowedTCPPorts = [
    443
    80
  ];

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = false;
    headers.set = {
      Referrer-Policy = mkDefault "origin-when-cross-origin";
      #Strict-Transport-Security = "$hsts_header";
      #Content-Security-Policy = ''"script-src 'self'; object-src 'none'; base-uri 'none';" always'';
      #X-Frame-Options = "DENY";
      #X-Content-Type-Options = "nosniff";
      #X-XSS-Protection = "1; mode=block";
    };
    commonHttpConfig = ''
      map $scheme $hsts_header {
          https   "max-age=31536000; includeSubdomains; preload";
      }
      #proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";
    '';
    clientMaxBodySize = mkDefault "512m";
    virtualHosts.fallback = {
      serverName = null;
      default = mkDefault true;
      locations."/".extraConfig = mkDefault ''
        return 404;
      '';
    };
  };
}
