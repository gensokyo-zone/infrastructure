{
  config,
  meta,
  lib,
  modulesPath,
  ...
}: let
  inherit (lib.modules) mkIf;
  inherit (lib.attrsets) genAttrs nameValuePair;
  inherit (builtins) listToAttrs;
  dexFiles = [
    "ca-key.pem"
    "ca.pem"
    "ca.srl"
    "csr.pem"
    "key.pem"
    "req.cnf"
  ];
in {
  imports = with meta; [
    (modulesPath + "/profiles/qemu-guest.nix")
    nixos.sops
    nixos.cloudflared
    nixos.k8s
  ];

  boot = {
    initrd.availableKernelModules = [
      "ata_piix"
      "uhci_hcd"
      "virtio_pci"
      "virtio_scsi"
      "sd_mod"
      "sr_mod"
    ];
    loader.grub.device = "/dev/sda";
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/5ab5efe2-0250-4bf1-8fd6-3725cdd15031";
    fsType = "ext4";
  };

  swapDevices = [
    {device = "/dev/disk/by-uuid/b374e454-7af5-46fc-b949-24e38a2216d5";}
  ];

  networking.interfaces.ens18 = mkIf (!config.networking.useNetworkd) {
    # TODO: stop using dhcp
    useDHCP = true;
  };

  sops.secrets = let
    dexCommon = {
      owner = "kubernetes";
    };
  in
    {
      cloudflare_kubernetes_tunnel = {
        owner = config.services.cloudflared.user;
      };
    }
    // (genAttrs (map (name: "dex-${name}") dexFiles) (_: dexCommon));

  environment.etc = listToAttrs (map (name: nameValuePair "dex-ssl/${name}" {source = config.sops.secrets."dex-${name}".path;}) dexFiles);

  services.cloudflared = let
    tunnelId = "3dde2376-1dd1-4282-b5a4-aba272594976";
  in {
    tunnels.${tunnelId} = {
      default = "http_status:404";
      credentialsFile = config.sops.secrets.cloudflare_kubernetes_tunnel.path;
      ingress = {
        "k8s.gensokyo.zone" = {
          service = "https://localhost:6443";
          originRequest.noTLSVerify = true;
        };
      };
    };
  };

  systemd.network.networks._00-local = {
    name = "ens18";
    matchConfig = {
      MACAddress = "BC:24:11:49:FE:DC";
      Type = "ether";
    };
    address = ["10.1.1.42/24"];
    gateway = ["10.1.1.1"];
    DHCP = "no";
  };

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "23.11";
}
