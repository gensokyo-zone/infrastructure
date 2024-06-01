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
    ports = {
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
          gatus.client.network = mkAlmostOptionDefault "ip4";
        };
      };
      ucp-ssl = {
        port = mkAlmostOptionDefault 8003;
        protocol = "https";
      };
      asterisk = {
        port = mkAlmostOptionDefault 8088;
        protocol = "http";
      };
      asterisk-ssl = {
        port = mkAlmostOptionDefault 8089;
        protocol = "https";
      };
    };
  };
}
