{ config, lib, ... }: with lib;

{
  networking.nftables.enable = true;
  networking.tempAddresses = "disabled";
}
