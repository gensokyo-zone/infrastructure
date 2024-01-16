{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkDefault;
in {
  config.services.cockroachdb = {
    locality = mkDefault "provider=local,network=gensokyo,host=${config.networking.hostName}";
  };
}
