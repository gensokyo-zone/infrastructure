{
  meta,
  config,
  lib,
  utils,
  pkgs,
  modulesPath,
  ...
}: let
  inherit (lib) mkIf;
  hddopts = ["luks" "discard" "noauto" "nofail"];
  md = {
    shadow = rec {
      name = "shadowlegend";
      device = "/dev/md/${name}";
      unit = utils.escapeSystemdPath device + ".device";
      where = "/mnt/shadow";
      mount = utils.escapeSystemdPath where + ".mount";
      service = "md-shadow.service";
      disk = "/dev/disk/by-uuid/84aafe0e-132a-4ee5-8c5c-c4a396b999bf";
      cryptDisks =
        lib.flip lib.mapAttrs {
          seagate0 = {
            device = "/dev/disk/by-uuid/78880135-6455-4603-ae07-4e044a77b740";
            keyFile = "/root/ST4000DM000-1F21.key";
            options = hddopts;
          };
          hgst = {
            device = "/dev/disk/by-uuid/4033c877-fa1f-4f75-b9de-07be84f83afa";
            keyFile = "/root/HGST-HDN724040AL.key";
            options = hddopts;
          };
        } (disk: attrs:
          attrs
          // {
            service = "systemd-cryptsetup@${disk}.service";
          });
    };
  };
in {
  imports = with meta;
    [
      (modulesPath + "/installer/scan/not-detected.nix")
      nixos.sops
      nixos.tailscale
      nixos.cloudflared
      nixos.nginx
      nixos.access.gensokyo
      nixos.access.zigbee2mqtt
      nixos.postgres
      nixos.vouch
      nixos.kanidm
      nixos.mosquitto
      nixos.zigbee2mqtt
      nixos.deluge
      nixos.syncplay
      nixos.home-assistant
      inputs.systemd2mqtt.nixosModules.default
      ./mediatomb.nix
      ./deluge.nix
      ./cloudflared.nix
    ];

  boot.supportedFilesystems = ["nfs"];

  services.udev.extraRules = ''
    SUBSYSTEM=="tty", GROUP="input", MODE="0660"
  '';

  services.cockroachdb.locality = "provider=local,network=gensokyo,host=${config.networking.hostName}";
  services.kanidm.serverSettings.db_fs_type = "zfs";

  sops.defaultSopsFile = ./secrets.yaml;

  networking = {
    useNetworkd = true;
    useDHCP = false;
  };
  services.resolved.enable = true;

  environment.systemPackages = [
    pkgs.cryptsetup
  ];

  boot = {
    loader = {
      systemd-boot = {
        enable = true;
      };
      efi = {
        canTouchEfiVariables = true;
      };
    };
    initrd = {
      availableKernelModules = ["xhci_pci" "ehci_pci" "ahci" "usbhid" "usb_storage" "sd_mod"];
    };
    kernelModules = ["kvm-intel"];
  };

  services.openiscsi = {
    enable = true;
    enableAutoLoginOut = true;
    name = "";
  };

  services.systemd2mqtt = {
    enable = true;
    user = "root";
    mqtt = {
      url = "tcp://localhost:1883";
      username = "systemd";
    };
    units = {
      ${md.shadow.mount} = {};
      "mediatomb.service" = mkIf config.services.mediatomb.enable {};
    };
  };

  environment.etc = {
    "iscsi/initiatorname.iscsi" = lib.mkForce {
      source = config.sops.secrets.openiscsi-config.path;
    };
    crypttab.text = let
      inherit (lib) concatStringsSep mapAttrsToList;
      cryptOpts = lib.concatStringsSep ",";
    in
      concatStringsSep "\n" (mapAttrsToList (
          disk: {
            device,
            keyFile,
            options,
            ...
          }: "${disk} ${device} ${keyFile} ${cryptOpts options}"
        )
        md.shadow.cryptDisks);
  };

  sops.secrets = {
    openiscsi-config = {};
    openiscsi-env = mkIf config.services.openiscsi.enableAutoLoginOut { };
    systemd2mqtt-env = {};
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/6c5d82b1-5d11-4c72-96c6-5f90e6ce57f5";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/85DC-72FA";
      fsType = "vfat";
    };
    ${md.shadow.where} = {
      device = md.shadow.disk;
      fsType = "xfs";
      options = [
        "x-systemd.automount"
        "noauto" "nofail"
        "x-systemd.requires=${md.shadow.service}"
        "x-systemd.after=${md.shadow.service}"
        "x-systemd.after=${md.shadow.unit}"
      ];
    };
  };
  systemd = let
    inherit (lib) getExe;
    serviceName = lib.removeSuffix ".service";
    toSystemdIni = pkgs.lib.generators.toINI {
      listsAsDuplicateKeys = true;
    };
    cryptServices = lib.mapAttrsToList (_: {service, ...}: service) md.shadow.cryptDisks;
  in {
    services = {
      nfs-mountd = {
        wants = ["network-online.target"];
      };
      mdmonitor.enable = false;
      ${serviceName md.shadow.service} = rec {
        restartIfChanged = false;
        wants = cryptServices ++ [ "iscsi.service" ];
        bindsTo = cryptServices;
        after = wants;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = "true";
          ExecStartPre = [
            "-${getExe pkgs.mdadm} --assemble --scan"
          ];
          ExecStart = [
            "${getExe pkgs.mdadm} --detail ${md.shadow.device}"
          ];
          ExecStop = [
            "${getExe pkgs.mdadm} --stop ${md.shadow.device}"
          ];
        };
      };
      iscsid = rec {
        wantedBy = cryptServices;
        before = wantedBy;
      };
      iscsi = let
        cfg = config.services.openiscsi;
      in mkIf cfg.enableAutoLoginOut rec {
        wantedBy = cryptServices;
        before = wantedBy;
        serviceConfig = {
          EnvironmentFile = [ config.sops.secrets.openiscsi-env.path ];
          ExecStartPre = [
            "${cfg.package}/bin/iscsiadm --mode discoverydb --type sendtargets --portal $DISCOVER_PORTAL --discover"
          ];
        };
      };
      systemd2mqtt = mkIf config.services.systemd2mqtt.enable rec {
        requires = mkIf config.services.mosquitto.enable ["mosquitto.service"];
        after = requires;
        serviceConfig.EnvironmentFile = [
          config.sops.secrets.systemd2mqtt-env.path
        ];
      };
    };
    units = {
      ${md.shadow.mount} = {
        overrideStrategy = "asDropin";
        text = toSystemdIni {
          Unit.BindsTo = [
            md.shadow.service
          ];
        };
      };
    };
    network = {
      networks.eno1 = {
        inherit (config.systemd.network.links.eno1) matchConfig;
        networkConfig = {
          DHCP = "yes";
          DNSDefaultRoute = true;
          MulticastDNS = true;
        };
      };
      links.eno1 = {
        matchConfig = {
          Type = "ether";
          Driver = "e1000e";
        };
        linkConfig = {
          WakeOnLan = "magic";
        };
      };
    };
  };

  swapDevices = lib.singleton {
    device = "/dev/disk/by-uuid/137605d3-5e3f-47c8-8070-6783ce651932";
  };

  system.stateVersion = "21.05";
}
