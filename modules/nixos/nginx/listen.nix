{
  config,
  lib,
  inputs,
  ...
}: let
  inherit (inputs.self.lib.lib) mkAlmostOptionDefault mkAddress6;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkBefore mkOptionDefault mkForce;
  inherit (lib.attrsets) attrValues mapAttrs;
  inherit (lib.lists) optional filter concatMap;
  inherit (config.services) nginx;
  listenModule = { config, virtualHost, listenKind, ... }: {
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
      listenParameters = mkOption {
        type = listOf str;
        internal = true;
      };
      listenConfigs = mkOption {
        type = listOf (separatedString " ");
        internal = true;
      };
      listenDirectives = mkOption {
        type = lines;
        internal = true;
      };
    };
    config = {
      enable = mkMerge [
        (mkIf (config.ssl && !virtualHost.ssl.enable) (mkForce false))
        (mkIf (listenKind == "streamServer" && !config.ssl && virtualHost.ssl.enable && virtualHost.ssl.force != false) (mkForce false))
      ];
      port = mkIf (listenKind == "virtualHost") (mkOptionDefault (
        if config.ssl then nginx.defaultSSLListenPort else nginx.defaultHTTPListenPort
      ));
      addresses = mkMerge [
        (mkOptionDefault virtualHost.listenAddresses')
        (mkIf (config.addr != null) (mkAlmostOptionDefault [ config.addr ]))
      ];
      listenParameters = mkOptionDefault (
        optional config.ssl "ssl"
        ++ optional virtualHost.default or false "default_server"
        ++ optional virtualHost.reuseport or false "reuseport"
        ++ optional config.proxyProtocol or false "proxy_protocol"
        ++ config.extraParameters
      );
      listenConfigs = let
        # TODO: handle quic listener..?
        mkListenHost = { addr, port }: let
          host =
            if addr != null then "${mkAddress6 addr}:${toString port}"
            else toString port;
        in assert port != null; host;
        mkDirective = addr: let
          host = mkListenHost { inherit addr; inherit (config) port; };
        in mkMerge (
          [ (mkBefore host) ]
          ++ config.listenParameters
        );
      in mkOptionDefault (map (mkDirective) config.addresses);
      listenDirectives = mkMerge (map (conf: mkOptionDefault "listen ${conf};") config.listenConfigs);
    };
  };
  listenType = { specialArgs, modules ? [ ] }: lib.types.submoduleWith {
    inherit specialArgs;
    modules = [ listenModule ] ++ modules;
  };
  hostModule = { nixosConfig, config, ... }: let
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
    options = with lib.types; {
      listen' = mkOption {
        type = attrsOf (listenType {
          specialArgs = {
            inherit nixosConfig;
            virtualHost = config;
            listenKind = "virtualHost";
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
  streamServerModule = { nixosConfig, config, ... }: let
    enabledListen = filter (port: port.enable) (attrValues config.listen);
  in {
    options = with lib.types; {
      listen = mkOption {
        type = attrsOf (listenType {
          specialArgs = {
            inherit nixosConfig;
            virtualHost = config;
            streamServer = config;
            listenKind = "streamServer";
          };
        });
        default = { };
      };
      listenAddresses = mkOption {
        type = nullOr (listOf str);
        default = null;
      };
      listenAddresses' = mkOption {
        type = listOf str;
        internal = true;
        description = "listenAddresses or defaultListenAddresses if empty";
      };
      reuseport = mkOption {
        type = types.bool;
        default = false;
        description = "only required on one host";
      };
    };

    config = {
      enable = mkIf (config.listen != { } && enabledListen == [ ]) (mkForce false);
      listenAddresses' = mkOptionDefault (
        if config.listenAddresses != null then config.listenAddresses else nginx.defaultListenAddresses
      );
      streamConfig = mkIf (config.listen != { }) (mkMerge (
        map (listen: mkBefore listen.listenDirectives) enabledListen
      ));
    };
  };
in {
  options.services.nginx = with lib.types; {
    virtualHosts = mkOption {
      type = attrsOf (submoduleWith {
        modules = [ hostModule ];
        shorthandOnlyDefinesConfig = true;
      });
    };
    stream.servers = mkOption {
      type = attrsOf (submoduleWith {
        modules = [ streamServerModule ];
        shorthandOnlyDefinesConfig = false;
      });
    };
  };
}
