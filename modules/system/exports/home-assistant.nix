{lib, gensokyo-zone, ...}: let
  inherit (gensokyo-zone.lib) mapAlmostOptionDefaults mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
  inherit (lib.attrsets) mapAttrs;
  inherit (lib.lists) all imap0;
  inherit (lib.trivial) id;
in {
  config.exports.services.home-assistant = { config, ... }: let
    mkAssertion = f: nixosConfig: let
      cfg = nixosConfig.services.home-assistant;
    in f nixosConfig cfg;
    assertPort = nixosConfig: cfg: {
      assertion = config.ports.default.port == cfg.config.http.server_port;
      message = "port mismatch";
    };
    assertHomekitPort = let
      portName = i: "homekit${toString i}";
      mkAssertPort = i: homekit: config.ports.${portName i}.port or null == homekit.port;
    in nixosConfig: cfg: {
      assertion = all id (imap0 mkAssertPort cfg.config.homekit);
      message = "homekit port mismatch";
    };
  in {
    id = mkAlmostOptionDefault "home";
    nixos = {
      serviceAttr = "home-assistant";
      assertions = mkIf config.enable [
        (mkAssertion assertPort)
        (mkAssertion assertHomekitPort)
      ];
    };
    defaults.port.listen = mkAlmostOptionDefault "lan";
    ports = mapAttrs (_: mapAlmostOptionDefaults) {
      default = {
        port = 8123;
        protocol = "http";
      };
      homekit0 = {
        port = 21063;
        transport = "tcp";
      };
      # TODO: cast udp port range 32768 to 60999
    };
  };
}
