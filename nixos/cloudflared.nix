{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkDefault;
in {
  config.services.cloudflared.enable = mkDefault true;
}
