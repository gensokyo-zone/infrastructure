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
    nameservers' = [
      #{ address = "8.8.8.8"; host = "dns.google"; }
      { address = "1.1.1.1"; host = "cloudflare-dns.com"; }
      { address = "1.0.0.1"; host = "cloudflare-dns.com"; }
    ];
  };

  # work around https://github.com/NixOS/nixpkgs/issues/132646
  system.nssDatabases.hosts = mkIf config.services.resolved.enable (
    mkOrder 450 [ "files" ]
  );
}
