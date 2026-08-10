{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkAfter mkOptionDefault;
  inherit (lib.strings) hasPrefix;
  inherit (lib.attrsets) mapAttrsToList getLib;
  inherit (lib.lists) concatMap;
  inherit (config.services.nginx) lua;
  cfg = lua;
  enabled = cfg.http.enable || cfg.upstream.enable;
  luaModuleFor = mod:
    if builtins.isString mod then cfg.luaPackage.pkgs.${mod}
    else mod;
  luaModulesFor = mod: [ mod ] ++ concatMap luaModulesFor mod.propagatedBuildInputs or [ ];
  luaModules = concatMap luaModulesFor (map luaModuleFor cfg.modules);
  luaPathFor = pkg: suffix: [
    "${getLib pkg}/lib/lua/${cfg.luaPackage.luaversion}/${suffix}"
    "${getLib pkg}/share/lua/${cfg.luaPackage.luaversion}/${suffix}"
  ];
  luaPkgPath = pkg:
    luaPathFor pkg "?.lua"
    ++ luaPathFor pkg "?/init.lua";
  luaCPkgPath = pkg: [
    "${getLib pkg}/lib/lua/${cfg.luaPackage.luaversion}/?.so"
  ];
  luaModule = {config, ...}: let
    cfg = config.lua;
    mkSetBy = var: value:
      if hasPrefix "/" "${value}"
      then "set_by_lua_file \$${var} ${value};"
      else ''
        set_by_lua_block ''$${var} {
          ${value}
        }
      '';
  in {
    options.lua = with lib.types; {
      access = {
        block = mkOption {
          type = lines;
          default = "";
        };
        files = mkOption {
          type = listOf path;
          default = [];
        };
      };
      set = mkOption {
        type = attrsOf (either path lines);
        default = {};
      };
    };
    config = {
      extraConfig = mkMerge [
        (mkIf (cfg.access.block != "") (assert lua.http.enable; ''
          access_by_lua_block {
            ${cfg.access.block}
          }
        ''))
        (mkIf (cfg.access.files != []) (assert lua.http.enable;
          mkMerge (
            map (file: "access_by_lua_file ${file};") cfg.access.files
          )))
        (mkIf (cfg.set != {}) (assert lua.http.enable && lua.ndk.enable;
          mkMerge (
            mapAttrsToList mkSetBy cfg.set
          )))
      ];
    };
  };
  locationModule = {config, ...}: {
    imports = [luaModule];
  };
  hostModule = {config, ...}: {
    imports = [luaModule];

    options = with lib.types; {
      locations = mkOption {
        type = attrsOf (submoduleWith {
          modules = [locationModule];
          shorthandOnlyDefinesConfig = true;
        });
      };
    };
  };
in {
  options.services.nginx = with lib.types; {
    lua = {
      ndk.enable = mkEnableOption "ngx_devel_kit";
      http.enable = mkEnableOption "ngx_http_lua_module";
      upstream.enable = mkEnableOption "ngx_http_lua_upstream";
      luaPackage = mkOption {
        type = package;
        default = pkgs.luajit_openresty;
      };
      modules = mkOption {
        type = listOf (either package str);
      };
      luaPath = mkOption {
        type = separatedString ";";
      };
      luaCPath = mkOption {
        type = separatedString ";";
      };
      pathDirectives = mkEnableOption "prefer lua_package_path over LUA_PATH";
    };
    virtualHosts = mkOption {
      type = attrsOf (submoduleWith {
        modules = [hostModule];
        shorthandOnlyDefinesConfig = true;
      });
    };
  };
  config = {
    services.nginx = {
      lua = {
        modules = ["lua-resty-core"];
        luaPath = mkMerge (
          concatMap luaPkgPath luaModules
          ++ [(mkAfter ";")]
        );
        luaCPath = mkMerge (
          concatMap luaCPkgPath luaModules
          ++ [(mkAfter ";")]
        );
      };
      additionalModules = mkMerge [
        (mkIf cfg.ndk.enable [pkgs.nginxModules.develkit])
        (mkIf cfg.http.enable [pkgs.nginxModules.lua])
        (mkIf cfg.upstream.enable [pkgs.nginxModules.lua-upstream])
      ];
      appendHttpConfig = mkIf (enabled && cfg.pathDirectives) ''
        lua_package_path '${cfg.luaPath}';
        lua_package_cpath '${cfg.luaCPath}';
      '';
    };
    systemd.services.nginx = mkIf config.services.nginx.enable {
      environment = mkIf (enabled && !cfg.pathDirectives) {
        LUA_PATH = mkOptionDefault cfg.luaPath;
        LUA_CPATH = mkOptionDefault cfg.luaCPath;
      };
      serviceConfig = mkIf enabled {
        SystemCallFilter = [ "@ipc" ];
      };
    };
  };
}
