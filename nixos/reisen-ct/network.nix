{
  lib,
  name,
  ...
}: let
  inherit (lib) mkDefault mkOverride;
in {
  services.resolved.enable = true;
}
