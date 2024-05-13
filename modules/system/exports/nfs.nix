{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mapAlmostOptionDefaults mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
  inherit (lib.attrsets) mapAttrs;
in {
  config.exports.services.nfs = {config, ...}: let
    mkAssertion = f: nixosConfig: let
      cfg = nixosConfig.services.nfs;
    in
      f nixosConfig cfg;
    mkAssertionPort = portName:
      mkAssertion (nixosConfig: cfg: let
        portAttr = "${portName}Port";
      in {
        assertion = mkAssertPort config.ports.${portName} cfg.server.${portAttr};
        message = "${portAttr} mismatch";
      });
    mkAssertPort = port: cfgPort: let
      cmpPort =
        if port.enable
        then port.port
        else null;
    in
      cfgPort == cmpPort;
  in {
    nixos = {
      serviceAttrPath = ["services" "nfs" "server"];
      assertions = mkIf config.enable [
        (mkAssertionPort "statd")
        (mkAssertionPort "lockd")
        (mkAssertionPort "mountd")
        (mkAssertion (nixosConfig: cfg: {
          assertion = nixosConfig.services.rpcbind.enable == config.ports.rpcbind.enable;
          message = "rpcbind enable mismatch";
        }))
      ];
    };
    # TODO: expose over wan
    defaults.port.listen = mkAlmostOptionDefault "lan";
    ports = mapAttrs (_: mapAlmostOptionDefaults) {
      default = {
        port = 2049;
        transport = "tcp";
      };
      udp = {
        port = config.ports.default.port;
        transport = "udp";
      };
      rpcbind = {
        port = 111;
        transport = "tcp";
      };
      rpcbind-udp = {
        port = config.ports.rpcbind.port;
        transport = "udp";
      };
      statd = {
        port = 4000;
        transport = "tcp";
      };
      statd-udp = {
        port = config.ports.statd.port;
        transport = "udp";
      };
      lockd = {
        port = 4001;
        transport = "tcp";
      };
      lockd-udp = {
        port = config.ports.lockd.port;
        transport = "udp";
      };
      mountd = {
        port = 4002;
        transport = "tcp";
      };
      mountd-udp = {
        port = config.ports.mountd.port;
        transport = "udp";
      };
    };
  };
}
