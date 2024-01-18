{ config, name, lib, ... }: with lib;

{
  networking = {
    nftables.enable = true;
    domain = mkDefault "gensokyo.zone";
    hostName = mkOverride 25 name;
  };
}
