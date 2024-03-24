{config, lib, inputs, ...}: let
  inherit (inputs.self.lib.lib) unmerged eui64 toHexStringLower;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkOptionDefault mkOverride;
  inherit (lib.attrsets) attrValues;
  inherit (lib.lists) elem findSingle;
  inherit (lib.strings) hasPrefix removePrefix replaceStrings;
  inherit (lib.trivial) mapNullable;
  mkAlmostOptionDefault = mkOverride 1250;
  cfg = config.proxmox.network;
  internalOffset = 32;
  networkInterfaceModule = { config, name, system, ... }: {
    options = with lib.types; {
      enable = mkEnableOption "network interface" // {
        default = true;
      };
      bridge = mkOption {
        type = str;
        default = "vmbr0";
      };
      id = mkOption {
        type = str;
        default = name;
      };
      name = mkOption {
        type = str;
      };
      macAddress = mkOption {
        type = nullOr str;
        default = null;
      };
      address4 = mkOption {
        type = nullOr (either (enum [ "dhcp" ]) str);
        default = null;
      };
      gateway4 = mkOption {
        type = nullOr str;
        default = null;
      };
      address6 = mkOption {
        type = nullOr (either (enum [ "auto" "dhcp" ]) str);
        default = null;
      };
      gateway6 = mkOption {
        type = nullOr str;
        default = null;
      };
      firewall.enable = mkEnableOption "firewall";
      vm.model = mkOption {
        type = enum [ "virtio" "e1000" "rtl8139" "vmxnet3" ];
        default = "virtio";
      };
      mdns = {
        enable = mkEnableOption "mDNS" // {
          default = system.proxmox.node.name == "reisen" && config.id == "net0";
        };
      };
      slaac = {
        postfix = mkOption {
          type = nullOr str;
        };
      };
      internal = {
        enable = mkEnableOption "internal network interface";
      };
      networkd = {
        enable = mkEnableOption "systemd.network" // {
          default = true;
        };
        networkSettings = mkOption {
          type = unmerged.types.attrs;
        };
      };
    };
    config = let
      conf = {
        name = mkMerge [
          (mkIf (hasPrefix "net" config.id && system.proxmox.container.enable) (mkOptionDefault ("eth" + removePrefix "net" config.id)))
          # VMs have names like `ens18` for net0...
        ];
        slaac.postfix = mkOptionDefault (mapNullable eui64 config.macAddress);
        gateway4 = mkMerge [
          (mkIf (system.proxmox.node.name == "reisen" && config.bridge == "vmbr0" && config.address4 != null && config.address4 != "dhcp") (mkAlmostOptionDefault "10.1.1.1"))
        ];
        networkd.networkSettings = {
          name = mkAlmostOptionDefault config.name;
          matchConfig = {
            MACAddress = mkIf (config.macAddress != null) (mkOptionDefault config.macAddress);
            Type = mkOptionDefault "ether";
          };
          linkConfig = mkMerge [
            (mkIf config.mdns.enable { Multicast = mkOptionDefault true; })
          ];
          networkConfig = mkMerge [
            (mkIf (config.address6 == "auto") {
              IPv6AcceptRA = true;
            })
            (mkIf config.mdns.enable {
              MulticastDNS = true;
            })
          ];
          address = mkMerge [
            (mkIf (! elem config.address4 [ null "dhcp" ]) [ config.address4 ])
            (mkIf (! elem config.address6 [ null "auto" "dhcp" ]) [ config.address6 ])
          ];
          gateway = mkMerge [
            (mkIf (config.gateway4 != null) [ config.gateway4 ])
            (mkIf (config.gateway6 != null) [ config.gateway6 ])
          ];
          DHCP = mkAlmostOptionDefault (
            if config.address4 == "dhcp" && config.address6 == "dhcp" then "yes"
            else if config.address6 == "dhcp" then "ipv6"
            else if config.address4 == "dhcp" then "ipv4"
            else "no"
          );
        };
      };
      confInternal = {
        name = mkIf system.proxmox.container.enable (mkAlmostOptionDefault "eth9");
        bridge = mkAlmostOptionDefault "vmbr9";
        address4 = mkAlmostOptionDefault "10.9.1.${toString (system.proxmox.vm.id - internalOffset)}/24";
        address6 = mkAlmostOptionDefault "fd0c::${toHexStringLower (system.proxmox.vm.id - internalOffset)}/64";
        macAddress = mkIf (system.proxmox.network.interfaces.net0.macAddress or null != null && hasPrefix "BC:24:11:" system.proxmox.network.interfaces.net0.macAddress) (mkAlmostOptionDefault (
          replaceStrings [ "BC:24:11:" ] [ "BC:24:19:" ] system.proxmox.network.interfaces.net0.macAddress
        ));
        networkd.networkSettings.linkConfig.RequiredForOnline = false;
      };
    in mkMerge [
      conf
      (mkIf config.internal.enable confInternal)
    ];
  };
in {
  options.proxmox.network = with lib.types; {
    interfaces = mkOption {
      type = attrsOf (submoduleWith {
        modules = [ networkInterfaceModule ];
        specialArgs = {
          system = config;
        };
      });
      default = { };
    };
    internal = {
      interface = mkOption {
        type = nullOr unspecified;
      };
    };
  };
  config.proxmox.network = {
    internal = {
      interface = mkOptionDefault (findSingle (interface: interface.internal.enable) null (throw "expected only one internal network interface") (attrValues cfg.interfaces));
    };
  };
}
