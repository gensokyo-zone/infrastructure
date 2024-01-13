{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge mkOptionDefault mkDefault;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.lists) any;
  cfg = config.services.postgresql;
  ensureUserModule = { config, ... }: {
    options = with lib.types; {
      tailscale = {
        allow = mkEnableOption "tailscale TCP connections";
        database = mkOption {
          type = str;
        };
      };
    };
    config = {
      tailscale.database = mkIf (config.ensureDBOwnership) (
        mkOptionDefault config.name
      );
    };
  };
in {
  options.services.postgresql = with lib.types; {
    ensureUsers = mkOption {
      type = listOf (submodule ensureUserModule);
    };
  };
  config.services.postgresql = {
    enableTCPIP = mkIf (any (user: user.tailscale.allow) cfg.ensureUsers) (
      mkDefault true
    );
    authentication = let
      allowTail = { database, user }: ''
        host ${database} ${user} fd7a:115c:a1e0::/96 md5
        host ${database} ${user} fd7a:115c:a1e0:ab12::/64 md5
        host ${database} ${user} 100.64.0.0/10 md5
      '';
    in mkMerge (map
      (user: mkIf user.tailscale.allow (
        allowTail { inherit (user.tailscale) database; user = user.name; }
      )) cfg.ensureUsers
    );
  };
}
