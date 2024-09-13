let
  serverModule = {
    config,
    lib,
    ...
  }: let
    inherit (lib.options) mkOption;
    inherit (lib.modules) mkIf mkOptionDefault;
    inherit (lib.strings) match toInt;
    inherit (lib.lists) elemAt;
  in {
    options = with lib.types; {
      bind = mkOption {
        type = str;
        readOnly = true;
      };
      port = mkOption {
        type = port;
        readOnly = true;
      };
    };
    config = let
      matched = match "^tcp://(.*):([0-9]+)$" config.uri;
      bind = elemAt matched 0;
      port = toInt (elemAt matched 1);
    in {
      bind = mkIf (matched != null) (mkOptionDefault bind);
      port = mkIf (matched != null) (mkOptionDefault port);
    };
  };
  nonServerModule = service: {
    config,
    lib,
    ...
  } @ args: let
    cfg = config.services.wyoming.${service};
    module = serverModule (args
      // {
        name = service;
        config = cfg;
      });
  in {
    options.services.wyoming.${service} = module.options;
    config.services.wyoming.${service} = module.config;
  };
in
  {
    config,
    lib,
    ...
  }: let
    inherit (lib.options) mkOption;
    inherit (lib.attrsets) genAttrs;
    serviceNames = ["piper" "faster-whisper"];
    nonServerNames = ["openwakeword" "satellite"];
    nonServerServices = map nonServerModule nonServerNames;
  in {
    imports = nonServerServices;

    options.services.wyoming = let
      mkServiceOptions = service:
        with lib.types; {
          servers = mkOption {
            type = attrsOf (submodule [serverModule]);
          };
        };
      serverServices = genAttrs serviceNames mkServiceOptions;
    in
      serverServices
      // {
      };
  }
