{lib, gensokyo-zone, ...}: let
  inherit (gensokyo-zone.lib) mapAlmostOptionDefaults mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
  inherit (lib.attrsets) mapAttrs filterAttrs mapAttrsToList;
  inherit (lib.lists) sort;
in {
  config.exports.services.sshd = { config, ... }: let
    mkAssertion = f: nixosConfig: let
      cfg = nixosConfig.services.openssh;
    in f nixosConfig cfg;
    sorted = sort (a: b: a > b);
    assertPorts = nixosConfig: cfg: let
      nixosPorts = cfg.ports;
      enabledPorts = filterAttrs (_: port: port.enable) config.ports;
      servicePorts = mapAttrsToList (_: port: port.port) enabledPorts;
    in {
      assertion = sorted nixosPorts == sorted servicePorts;
      message = "port mismatch: ${toString nixosPorts} != ${toString servicePorts}";
    };
  in {
    id = mkAlmostOptionDefault "ssh";
    nixos = {
      serviceAttr = "openssh";
      assertions = mkIf config.enable [
        (mkAssertion assertPorts)
      ];
    };
    defaults.port.listen = mkAlmostOptionDefault "wan";
    ports = mapAttrs (_: mapAlmostOptionDefaults) {
      public = {
        port = 62954;
        transport = "tcp";
      };
      standard = {
        port = 22;
        transport = "tcp";
        listen = "lan";
      };
    };
  };
}
