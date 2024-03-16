{
  inputs,
  name,
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkOrder mkDefault mkOverride;
  inherit (inputs.self.lib.lib) domain;
in {
  networking = {
    nftables.enable = true;
    domain = mkDefault domain;
    hostName = mkOverride 25 name;
  };

  # work around https://github.com/NixOS/nixpkgs/issues/132646
  system.nssDatabases.hosts = mkIf config.services.resolved.enable (
    mkOrder 500 [ "files" ]
  );
}
