{
  config,
  lib,
  access,
  gensokyo-zone,
  ...
}:
let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.modules) mkIf mkOptionDefault;
  inherit (config.services) nginx;
  portPlaintext = 1883;
  portSsl = 8883;
  system = access.systemForService "mosquitto";
  inherit (system.exports.services) mosquitto;
in {
  config = {
    services.nginx = {
      stream = {
        upstreams = let
          addr = mkAlmostOptionDefault (access.getAddressFor system.name "lan");
        in {
          mqtt.servers.access = {
            inherit addr;
            port = mkOptionDefault mosquitto.ports.default.port;
          };
          mqtts = {
            enable = mkAlmostOptionDefault mosquitto.ports.ssl.enable;
            ssl.enable = true;
            servers.access = {
              inherit addr;
              port = mkOptionDefault mosquitto.ports.ssl.port;
            };
          };
        };
        servers.mosquitto = {
          listen = {
            mqtt.port = mkOptionDefault portPlaintext;
            mqtts = {
              ssl = true;
              port = mkOptionDefault portSsl;
            };
          };
          proxy.upstream = mkAlmostOptionDefault (
            if nginx.stream.upstreams.mqtts.enable then "mqtts" else "mqtt"
          );
        };
      };
    };

    networking.firewall = {
      interfaces.local.allowedTCPPorts = let
        inherit (nginx.stream.servers.mosquitto) listen;
      in [
        listen.mqtt.port
        (mkIf listen.mqtts.enable listen.mqtts.port)
      ];
    };
  };
}
