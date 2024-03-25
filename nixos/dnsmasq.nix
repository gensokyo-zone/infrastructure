{
  config,
  lib,
  inputs,
  ...
}: let
  inherit (inputs.self.lib) generate;
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkBefore mkDefault mkForce;
  inherit (lib.attrsets) filterAttrs mapAttrsToList nameValuePair listToAttrs;
  inherit (lib.lists) filter concatLists;
  inherit (lib.strings) hasPrefix replaceStrings concatStringsSep;
  inherit (lib.trivial) mapNullable;
  cfg = config.services.dnsmasq;
  mkHostRecordPairs = systemName: system: [
    (mkHostRecordPair "int" systemName system)
    (mkHostRecordPair "local" systemName system)
    #(mkHostRecordPair "tail" systemName system)
  ];
  mapDynamic4 = replaceStrings [ "10.1.1." ] [ "0.0.0." ];
  mapDynamic6 = replaceStrings [ "fd0a::" ] [ "2001::" ];
  mkDynamicHostRecord = systemName: system: let
    address4 = system.network.local.address4 or null;
    address6 = system.network.local.address6 or null;
  in concatStringsSep "," ([
    "${systemName}.${config.networking.domain}"
  ] ++ lib.optional (address4 != null)
    (toString (mapNullable mapDynamic4 address4))
  ++ lib.optional (address6 != null)
    (toString (mapNullable mapDynamic6 address6))
  ++ lib.singleton
    cfg.dynamic.interface
  );
  mkHostRecordPair = network: systemName: system: let
    address4 = system.network.${network}.address4 or null;
    address6 = system.network.${network}.address6 or null;
  in nameValuePair
    "${systemName}.${network}.${config.networking.domain}"
    (concatStringsSep "," (
    lib.optional (address4 != null)
      (toString address4)
    ++ lib.optional (address6 != null)
      (toString address6)
    ));
  systemHosts = filterAttrs (_: value: value != "") (
    listToAttrs (concatLists (mapAttrsToList mkHostRecordPairs generate.reisen.systems))
  );
  mkHostRecord = name: record: "${name},${record}";
  filterns = ns: !hasPrefix "127.0.0" ns || ns == "::1";
  filterns' = ns: ns.enable && filterns ns.address;
in {
  options.services.dnsmasq = with lib.types; {
    resolveLocalQueries' = mkOption {
      type = bool;
      description = "add to resolv.conf, ignore the origin upstream option thanks";
      default = true;
    };
    dynamic.interface = mkOption {
      type = str;
      default = "eth0";
    };
  };
  config = {
    services.dnsmasq = {
      enable = mkDefault true;
      resolveLocalQueries = mkForce false;
      settings = {
        host-record = mapAttrsToList mkHostRecord systemHosts;
        dynamic-host = mapAttrsToList mkDynamicHostRecord generate.reisen.systems;
        server =
          if config.networking.nameservers' != [ ] then map (ns: ns.address) (filter filterns' config.networking.nameservers')
          else filter filterns config.networking.nameservers
        ;
        max-cache-ttl = 60;
      };
    };
    services.resolved = mkIf cfg.enable {
      extraConfig = ''
        DNSStubListener=no
      '';
    };
    networking = mkIf cfg.enable {
      firewall = {
        interfaces.local.allowedTCPPorts = [ 53 ];
        interfaces.local.allowedUDPPorts = [ 53 ];
      };
      nameservers' = mkIf cfg.resolveLocalQueries' (mkBefore [
        { address = "127.0.0.1"; }
      ]);
    };
  };
}
