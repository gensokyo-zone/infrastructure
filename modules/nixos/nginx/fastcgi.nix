let
  locationModule = {
    config,
    virtualHost,
    nixosConfig,
    xvars,
    gensokyo-zone,
    lib,
    ...
  }: let
    inherit (gensokyo-zone.lib) mapOptionDefaults mkAlmostBefore mkJustAfter mkAlmostOptionDefault;
    inherit (lib.options) mkOption mkEnableOption;
    inherit (lib.modules) mkIf mkMerge;
    inherit (lib.attrsets) attrNames filterAttrs mapAttrsToList;
    inherit (lib.trivial) id;
    inherit (nixosConfig.services) nginx;
    cfg = config.fastcgi;
    passHeaders = attrNames (filterAttrs (_: id) cfg.passHeaders);
    params = filterAttrs (_: value: value != null) cfg.params;
  in {
    options.fastcgi = with lib.types; {
      enable = mkEnableOption "fastcgi_pass";
      phpfpmPool = mkOption {
        type = nullOr str;
        default = null;
      };
      includeDefaults = mkOption {
        type = bool;
        default = true;
      };
      passHeaders = mkOption {
        type = attrsOf bool;
        default = { };
        description = "fastcgi_pass_header";
      };
      socket = mkOption {
        type = nullOr path;
      };
      params = mkOption {
        type = attrsOf (nullOr str);
      };
    };

    config = {
      fastcgi = {
        socket = mkIf (cfg.phpfpmPool != null) (mkAlmostOptionDefault
          nixosConfig.services.phpfpm.pools.${cfg.phpfpmPool}.socket
        );
        params = mapOptionDefaults {
          HTTPS = "${xvars.get.https} if_not_empty";
          REQUEST_SCHEME = xvars.get.scheme;
          HTTP_HOST = xvars.get.host;
          HTTP_REFERER = "${xvars.get.referer} if_not_empty";
          REMOTE_ADDR = xvars.get.remote_addr;
          # TODO: SERVER_ADDR
          # TODO: SERVER_PORT
          # TODO: SERVER_NAME?
        };
      };
      extraConfig = let
        passHeadersConfig = map (header: "fastcgi_pass_header ${xvars.escapeString header};") passHeaders;
        paramsConfig = mapAttrsToList (param: value: mkJustAfter "fastcgi_param ${param} ${xvars.escapeString value};") params;
      in mkIf cfg.enable (mkMerge ([
        (mkIf cfg.includeDefaults (mkAlmostBefore ''
          include ${nginx.package}/conf/fastcgi.conf;
        ''))
        (mkIf (cfg.socket != null) (mkJustAfter ''
          fastcgi_pass unix:${cfg.socket};
        ''))
      ] ++ passHeadersConfig
      ++ paramsConfig));
    };
  };
  hostModule = {config, lib, ...}: let
    inherit (lib.options) mkOption;
  in {
    options = with lib.types; {
      locations = mkOption {
        type = attrsOf (submodule [locationModule]);
      };
    };
  };
in {
  lib,
  ...
}: let
  inherit (lib.options) mkOption;
in {
  options = with lib.types; {
    services.nginx.virtualHosts = mkOption {
      type = attrsOf (submodule [hostModule]);
    };
  };
}
