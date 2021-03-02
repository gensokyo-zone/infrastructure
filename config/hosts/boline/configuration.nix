{ config, pkgs, ... }:

{
  imports = [
    ./hardware.nix
    #./wireguard.nix
  ];

  meta.deploy.profiles = [ ];
  meta.deploy.ssh.host = "boline.kittywit.ch";

  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/vda";

  networking = {
    hostName = "boline";
    domain = "kittywit.ch";
    hostId = "0417b551";
    useDHCP = false;
    interfaces.ens3.ipv4.addresses = [{
      address = "104.244.73.10";
      prefixLength = 24;
    }];
    defaultGateway = "104.244.73.1";
    nameservers = [ "1.1.1.1" ];
  };

  system.stateVersion = "20.09";
}

