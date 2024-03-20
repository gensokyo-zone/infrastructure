final: prev: let
  inherit (final) lib;
  luaOverlay = luafinal: luaprev: {
    lua-resty-core = luaprev.lua-resty-core.overrideAttrs (old: rec {
      version = lib.warnIf (old.version != "0.1.24") "lua-resty-core updated upstream" "0.1.28";
      src = old.src.override {
        rev = "v${version}";
        sha256 = "sha256-RJ2wcHTu447wM0h1fa2qCBl4/p9XL6ZqX9pktRW64RI=";
      };
    });
  };
in {
  nginxModules = prev.nginxModules // {
    lua = let
      inherit (prev.nginxModules) lua;
    in lua // lib.warnIf (lua.version != "0.10.26") "nginxModules.lua updated upstream" {
      preConfigure = lib.replaceStrings [ "patch " ] [ "#patch " ] lua.preConfigure;
    };
  };
  luaInterpreters = prev.luaInterpreters.override (old: {
    callPackage = final.newScope {
      packageOverrides = lib.composeExtensions (final.packageOverrides or (_: _: { })) luaOverlay;
    };
  });
}
