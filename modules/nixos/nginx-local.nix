{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkBefore;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.strings) optionalString;
  inherit (config.services) tailscale;
  localModule = { config, ... }: {
    options = with lib.types; {
      local = {
        enable = mkEnableOption "local traffic only";
      };
    };
    config = mkIf config.local.enable {
      extraConfig = let
        tailscaleAllow = ''
          allow fd7a:115c:a1e0::/96;
          allow fd7a:115c:a1e0:ab12::/64;
          allow 100.64.0.0/10;
        '';
      in mkBefore ''
        allow 127.0.0.0/8;
        allow ::1;
        allow 10.1.1.0/24;
        allow fd0a::/64;
        allow fe80::/64;
        ${optionalString tailscale.enable tailscaleAllow}
          deny all;
      '';
    };
  };
in {
  options = with lib.types; {
    services.nginx.virtualHosts = mkOption {
      type = attrsOf (submodule localModule);
    };
  };
}
