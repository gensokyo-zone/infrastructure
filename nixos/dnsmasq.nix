{
  config,
  lib,
  access,
  gensokyo-zone,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkMerge mkBefore mkDefault mkForce;
  inherit (lib.attrsets) filterAttrs mapAttrsToList nameValuePair listToAttrs;
  inherit (lib.lists) filter optional singleton concatLists;
  inherit (lib.strings) hasPrefix replaceStrings concatStringsSep;
  inherit (lib.trivial) mapNullable flip;
  cfg = config.services.dnsmasq;
  inherit (gensokyo-zone) systems;
  localSystems = filterAttrs (_: system:
    system.config.access.online.enable && system.config.network.networks.local.enable or false
  ) systems;
  mkHostRecordPairs = _: system: [
    (mkHostRecordPair "int" system)
    (mkHostRecordPair "local" system)
    (mkHostRecordPair "tail" system)
  ];
  mapDynamic4 = replaceStrings [ "10.1.1." ] [ "0.0.0." ];
  mapDynamic6 = replaceStrings [ "fd0a::" ] [ "2001::" ];
  mkDynamicHostRecord = _: system: let
    address4 = system.config.network.networks.local.address4 or null;
    address6 = system.config.network.networks.local.address6 or null;
  in concatStringsSep "," ([
    system.config.access.fqdn
  ] ++ optional (address4 != null)
    (toString (mapNullable mapDynamic4 address4))
  ++ optional (address6 != null)
    (toString (mapNullable mapDynamic6 address6))
  ++ singleton
    cfg.dynamic.interface
  );
  mkHostRecordPair = network: system: let
    address4 = system.config.network.networks.${network}.address4 or null;
    address6 = system.config.network.networks.${network}.address6 or null;
    fqdn = system.config.network.networks.${network}.fqdn or null;
  in nameValuePair
    (if fqdn != null then fqdn else "${network}.${system.config.access.fqdn}")
    (concatStringsSep "," (
    optional (address4 != null)
      (toString address4)
    ++ optional (address6 != null)
      (toString address6)
    ));
  systemHosts = filterAttrs (_: value: value != "") (
    listToAttrs (concatLists (mapAttrsToList mkHostRecordPairs systems))
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
      default = config.systemd.network.networks._00-local.name or "eth0";
    };
    bedrockConnect = {
      address = mkOption {
        type = nullOr str;
      };
      address6 = mkOption {
        type = nullOr str;
      };
    };
  };
  config = {
    services.dnsmasq = {
      enable = mkDefault true;
      resolveLocalQueries = mkForce false;
      settings = {
        host-record = let
          bedrockRecord = concatStringsSep "," (
            optional (cfg.bedrockConnect.address != null) cfg.bedrockConnect.address
            ++ optional (cfg.bedrockConnect.address6 != null) cfg.bedrockConnect.address6
          );
          bedrockRecordNames = [
            # https://github.com/Pugmatt/BedrockConnect?tab=readme-ov-file#using-your-own-dns-server
            "geo.hivebedrock.network"
            "hivebedrock.network"
            "play.inpvp.net"
            "mco.lbsg.net"
            "play.galaxite.net"
            "mco.cubecraft.net"
          ];
          bedrockRecords = map (flip mkHostRecord bedrockRecord) bedrockRecordNames;
        in mkMerge [
          (mapAttrsToList mkHostRecord systemHosts)
          (mkIf (cfg.bedrockConnect.address != null || cfg.bedrockConnect.address6 != null) bedrockRecords)
        ];
        dynamic-host = mapAttrsToList mkDynamicHostRecord localSystems;
        server =
          if config.networking.nameservers' != [ ] then map (ns: ns.address) (filter filterns' config.networking.nameservers')
          else filter filterns config.networking.nameservers
        ;
        max-cache-ttl = 60;
      };
      bedrockConnect = let
        system = access.systemForService "minecraft-bedrock-server";
      in {
        address = mkDefault (access.getAddress4For system.name "local");
        address6 = mkDefault (access.getAddress6For system.name "local");
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
