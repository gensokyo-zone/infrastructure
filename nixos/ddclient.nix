{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge mkDefault mkAfter mkForce;
  cfg = config.services.ddclient;
in {
  services.ddclient = {
    enable = mkDefault true;
    quiet = mkDefault true;
    username = mkDefault "token";
    protocol = mkDefault "cloudflare";
    zone = mkDefault config.networking.domain;
    use = "no";
    usev6 = mkIf config.networking.enableIPv6 (mkDefault "webv6, webv6=https://ipv6.nsupdate.info/myip");
    usev4 = mkDefault "webv4, webv6=https://ipv6.nsupdate.info/myip";
    domains = [];
    extraConfig = ''
      max-interval=1d
    '';
    passwordFile = config.sops.secrets.dyndns_cloudflare_token.path;
  };
  systemd.services.ddclient = mkIf cfg.enable rec {
    wants = ["network-online.target"];
    after = wants;
    wantedBy = mkForce [];
    serviceConfig = {
      ExecStartPre = let
        inherit (config.systemd.services.ddclient.serviceConfig) RuntimeDirectory;
        prestart-domains = pkgs.writeShellScript "ddclient-prestart-domains" ''
          cat ${config.sops.secrets.dyndns_ddclient_domains.path} >> /run/${RuntimeDirectory}/ddclient.conf
        '';
      in
        mkAfter ["!${prestart-domains}"];
      TimeoutStartSec = 90;
      LogFilterPatterns = [
        "~WARNING"
      ];
    };
  };

  sops.secrets = let
    sopsFile = mkDefault ./secrets/dyndns.yaml;
  in {
    dyndns_cloudflare_token = {
      inherit sopsFile;
    };
    dyndns_ddclient_domains = {
      inherit sopsFile;
    };
  };
}
