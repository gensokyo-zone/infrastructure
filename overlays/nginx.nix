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
    restyCoresForNgxHttp = {
      "0.10.31" = {
        nixpkgsVersion = "0.1.32";
        version = "0.1.34rc3";
        sha256 = "sha256-+rtbaHEqKSvaba+zZwRUnUsdu3Jndi8OVGUtFC55Fts=";
        #version = "0.1.34";
      };
      "0.10.32" = {
        nixpkgsVersion = "0.1.32";
        version = "0.1.35rc1";
        sha256 = "sha256-dqHkcYdZZY84N72a9hY6YuiJiw3Ivz+t9r6pbsX50II=";
        #version = "0.1.35";
      };
      /*"0.10.26" = {
        nixpkgsVersion = "0.1.24";
        version = "0.1.28";
        sha256 = "sha256-RJ2wcHTu447wM0h1fa2qCBl4/p9XL6ZqX9pktRW64RI=";
      };*/
    };
    ngxLuaVersion = final.nginxModules.lua.version;
    restyCoreMismatch = restyCoresForNgxHttp.${ngxLuaVersion}.version or luaprev.lua-resty-core.version != luaprev.lua-resty-core.version;
  in {
    lua-resty-core = if restyCoreMismatch
      then mkRestyCore restyCoresForNgxHttp.${ngxLuaVersion}
      else luaprev.lua-resty-core;
    /*luarocks_bootstrap = luaprev.luarocks_bootstrap.overrideAttrs (old: let
      inherit (luafinal) lua;
    in {
      # work around regression caused by https://github.com/NixOS/nixpkgs/pull/318852
      postInstall = lib.replaceStrings [ "${lua.luaOnBuild}" ] [ "${lua}" ] old.postInstall;
    });*/
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
