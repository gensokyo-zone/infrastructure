{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  cfg = config.services.nginx;
in {
  networking.firewall.interfaces.local.allowedTCPPorts = let
    inherit (cfg.ssl) preread;
  in
    mkIf cfg.enable [
      (
        if preread.enable
        then preread.serverPort
        else cfg.defaultSSLListenPort
      )
      cfg.defaultHTTPListenPort
    ];

  services.nginx = {
    enable = true;
    enableReload = mkDefault true;
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
    accessLog.format = mkDefault "combined_host";
    commonHttpConfig = ''
      map $scheme $hsts_header {
          https   "max-age=31536000; includeSubdomains; preload";
      }
      log_format combined_host '$remote_addr@$scheme'
        ' - $remote_user@$host@$server_name:$server_port'
        ' [$time_local]'
        ' "$request" $status $body_bytes_sent'
        ' "$http_referer" "$http_user_agent"';
    '';
    clientMaxBodySize = mkDefault "512m";
    virtualHosts.fallback = {
      serverName = null;
      default = mkDefault true;
      reuseport = mkDefault true;
      locations."/".extraConfig = ''
        return 404;
      '';
    };
  };
}
