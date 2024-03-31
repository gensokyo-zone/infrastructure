{
  config,
  lib,
  inputs,
  ...
}:
let
  inherit (inputs.self.lib.lib) mkAlmostOptionDefault;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkOptionDefault;
  inherit (config.services) nginx;
  access = nginx.access.mosquitto;
  portPlaintext = 1883;
  portSsl = 8883;
in {
  options.services.nginx.access.mosquitto = with lib.types; {
    enable = mkEnableOption "MQTT proxy";
    host = mkOption {
      type = str;
    };
    port = mkOption {
      type = port;
      default = portPlaintext;
    };
    bind = {
      sslPort = mkOption {
        type = port;
        default = portSsl;
      };
      port = mkOption {
        type = port;
        default = portPlaintext;
      };
    };
  };
  config = {
    services.nginx = {
      stream = {
        upstreams.mosquitto = {
          servers.access = {
            addr = mkAlmostOptionDefault access.host;
            port = mkOptionDefault access.port;
          };
        };
        servers.mosquitto = {
          listen = {
            mqtt.port = portPlaintext;
            mqtts = {
              ssl = true;
              port = portSsl;
            };
          };
          extraConfig = let
            proxySsl = port: mkIf (port == portSsl) ''
              proxy_ssl on;
              proxy_ssl_verify off;
            '';
          in mkMerge [
            "proxy_pass ${nginx.stream.upstreams.mosquitto.name};"
            (proxySsl access.port)
          ];
        };
      };
    };

    networking.firewall = {
      allowedTCPPorts = [
        access.bind.port
        (mkIf nginx.stream.servers.mosquitto.listen.mqtts.enable access.bind.sslPort)
      ];
    };
  };
}
