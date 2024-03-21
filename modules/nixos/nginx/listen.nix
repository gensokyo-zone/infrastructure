{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkOptionDefault mkForce mkOverride mkRenamedOptionModule;
  inherit (lib.attrsets) attrValues mapAttrs mapAttrsToList;
  inherit (lib.lists) filter concatMap;
  mkAlmostOptionDefault = mkOverride 1250;
  inherit (config.services) nginx;
  listenModule = { config, virtualHost, ... }: {
    options = with lib.types; {
      enable = mkEnableOption "this port" // {
        default = true;
      };
      addr = mkOption {
        type = nullOr str;
        default = null;
        description = "shorthand to override config.addresses";
      };
      addresses = mkOption {
        type = listOf str;
        description = "applies to all listen addresses unless set";
        defaultText = "virtualHost.listenAddresses'";
      };
      ssl = mkOption {
        type = bool;
        default = false;
      };
      port = mkOption {
        type = nullOr port;
      };
      extraParameters = mkOption {
        type = listOf str;
        default = [ ];
      };
      proxyProtocol = mkOption {
        type = bool;
        default = false;
      };
    };
    config = {
      enable = mkIf (config.ssl && !virtualHost.ssl.enable) (mkForce false);
      port = mkOptionDefault (
        if config.ssl then nginx.defaultSSLListenPort else nginx.defaultHTTPListenPort
      );
      addresses = mkMerge [
        (mkOptionDefault virtualHost.listenAddresses')
        (mkIf (config.addr != null) (mkAlmostOptionDefault [ config.addr ]))
      ];
    };
  };
  hostModule = { config, ... }: let
    cfg = attrValues config.listen';
    enabledCfg = filter (port: port.enable) cfg;
    mkListen = listen: addr: let
      listenAttrs = {
        inherit addr;
        inherit (listen) port ssl extraParameters proxyProtocol;
      };
    in mapAttrs (_: mkAlmostOptionDefault) listenAttrs;
    mkListens = listen: map (mkListen listen) listen.addresses;
  in {
    imports = [
      (mkRenamedOptionModule [ "listenPorts" ] [ "listen'" ])
    ];
    options = with lib.types; {
      listen' = mkOption {
        type = attrsOf (submoduleWith {
          modules = [ listenModule ];
          specialArgs = {
            virtualHost = config;
          };
        });
        default = { };
      };
      listenAddresses' = mkOption {
        type = listOf str;
        description = "listenAddresses or defaultListenAddresses if empty";
      };
    };

    config = {
      enable = mkIf (cfg != [ ] && enabledCfg == [ ]) (mkForce false);
      listenAddresses' = mkOptionDefault (
        if config.listenAddresses != [ ] then config.listenAddresses else nginx.defaultListenAddresses
      );
      listen = mkIf (cfg != { }) (mkAlmostOptionDefault (
        concatMap (mkListens) enabledCfg
      ));
    };
  };
in {
  options = with lib.types; {
    services.nginx.virtualHosts = mkOption {
      type = attrsOf (submoduleWith {
        modules = [ hostModule ];
        shorthandOnlyDefinesConfig = true;
      });
    };
  };
}
