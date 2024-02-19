{
  inputs,
  name,
  lib,
  ...
}: let
  inherit (lib.modules) mkDefault mkOverride;
  inherit (inputs.self.lib.lib) domain;
in {
  networking = {
    nftables.enable = true;
    domain = mkDefault domain;
    hostName = mkOverride 25 name;
  };
}
