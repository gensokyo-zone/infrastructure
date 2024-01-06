{ config, name, lib, ... }: with lib;

{
  networking = {
    nftables.enable = true;
    tempAddresses = "disabled";
    domain = mkDefault "gensokyo.zone";
    hostName = mkOverride 25 name;
  };
}
