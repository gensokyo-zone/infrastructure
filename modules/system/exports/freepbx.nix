{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
in {
  config.exports.services.freepbx = {config, ...}: {
    displayName = mkAlmostOptionDefault "FreePBX";
    id = mkAlmostOptionDefault "pbx";
    ports = let
      ucpGtatus = {
        client.network = mkAlmostOptionDefault "ip4";
        http = {
          websocket.enable = mkAlmostOptionDefault true;
          path = mkAlmostOptionDefault "/socket.io/?transport=websocket";
          statusCondition = mkAlmostOptionDefault "[BODY] == pat(*\"sid\":*)";
        };
      };
    in {
      http = {
        displayName = mkAlmostOptionDefault null;
        port = mkAlmostOptionDefault 80;
        protocol = "http";
        status.enable = mkAlmostOptionDefault true;
      };
      https = {
        port = mkAlmostOptionDefault 443;
        protocol = "https";
      };
      ucp = {
        port = mkAlmostOptionDefault 8001;
        protocol = "http";
        displayName = mkAlmostOptionDefault "UCP";
        status = {
          enable = mkAlmostOptionDefault config.ports.http.status.enable;
          gatus = ucpGtatus;
        };
      };
      ucp-ssl = {
        port = mkAlmostOptionDefault 8003;
        protocol = "https";
        status.gatus = ucpGtatus;
      };
      asterisk = {
        port = mkAlmostOptionDefault 8088;
        protocol = "http";
        prometheus.exporter.enable = let
          sslPort = config.ports.asterisk-ssl;
        in mkAlmostOptionDefault (!sslPort.enable || !sslPort.prometheus.exporter.enable);
      };
      asterisk-ssl = {
        port = mkAlmostOptionDefault 8089;
        protocol = "https";
        prometheus.exporter.enable = mkAlmostOptionDefault true;
      };
      operator = {
        enable = mkAlmostOptionDefault false;
        port = mkAlmostOptionDefault 58080;
        protocol = "http";
      };
    };
  };
}
