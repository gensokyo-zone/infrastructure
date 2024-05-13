final: prev: let
  inherit (final) lib;
  luaOverlay = luafinal: luaprev: let
    mkRestyCore = {
      nixpkgsVersion,
      version,
      sha256,
    }:
      luaprev.lua-resty-core.overrideAttrs (old: {
        version = lib.warnIf (old.version != nixpkgsVersion) "lua-resty-core updated upstream" version;
        src = old.src.override {
          rev = "v${version}";
          inherit sha256;
        };
      });
  in {
    #lua-resty-core = mkRestyCore { nixpkgsVersion = "0.1.24"; version = "0.1.28"; sha256 = "sha256-RJ2wcHTu447wM0h1fa2qCBl4/p9XL6ZqX9pktRW64RI="; };
  };
in {
  nginxModules =
    prev.nginxModules
    // {
      lua = let
        inherit (prev.nginxModules) lua;
      in
        lua
        // lib.warnIf (lua.version != "0.10.26") "nginxModules.lua updated upstream" {
          preConfigure = lib.replaceStrings ["patch "] ["#patch "] lua.preConfigure;
        };
    };
  luaInterpreters = prev.luaInterpreters.override (old: {
    callPackage = final.newScope {
      packageOverrides = lib.composeExtensions (final.packageOverrides or (_: _: {})) luaOverlay;
    };
  });
}
