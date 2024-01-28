{
  inputs,
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge mkDefault mkOptionDefault;
  inherit (lib.options) mkOption;
  inherit (lib.lists) optionals;
  inherit (lib.strings) concatStringsSep;
  inherit (config.services) tailscale avahi;
  inherit (config) networking;
  inherit (networking) hostName;
  cidrModule = { config, ... }: {
    options = with lib.types; {
      all = mkOption {
        type = listOf str;
        readOnly = true;
      };
      v4 = mkOption {
        type = listOf str;
        default = [ ];
      };
      v6 = mkOption {
        type = listOf str;
        default = [ ];
      };
    };
    config.all = mkOptionDefault (
      config.v4
      ++ optionals networking.enableIPv6 config.v6
    );
  };
in {
  options.networking.access = with lib.types; {
    hostnameForNetwork = mkOption {
      type = attrsOf str;
      default = { };
    };
    cidrForNetwork = mkOption {
      type = attrsOf (submodule cidrModule);
      default = { };
    };
  };

  config.networking.access = {
    hostnameForNetwork = {
      local = let
        eth0 = config.systemd.network.networks.eth0 or { };
        hasStaticAddress = eth0.address or [ ] != [ ] || eth0.addresses or [ ] != [ ];
        hasSLAAC = eth0.slaac.enable or false;
      in mkMerge [
        (mkIf (hasStaticAddress || hasSLAAC) (mkDefault "${hostName}.local.${config.networking.domain}"))
        (mkIf (avahi.enable && avahi.publish.enable) (mkOptionDefault "${hostName}.local"))
      ];
      tail = mkIf tailscale.enable "${hostName}.tail.${config.networking.domain}";
      global = mkIf (networking.enableIPv6 && networking.tempAddresses == "disabled") "${hostName}.${config.networking.domain}";
    };
    cidrForNetwork = {
      loopback = {
        v4 = [
          "127.0.0.0/8"
        ];
        v6 = [
          "::1"
        ];
      };
      local = {
        v4 = [
          "10.1.1.0/24"
        ];
        v6 = [
          "fd0a::/64"
          "fe80::/64"
        ];
      };
      tail = mkIf tailscale.enable {
        v4 = [
          "100.64.0.0/10"
        ];
        v6 = [
          "fd7a:115c:a1e0::/96"
          "fd7a:115c:a1e0:ab12::/64"
        ];
      };
    };
  };

  config.networking.firewall = {
    interfaces.local = {
      nftables.conditions = [
        "ip saddr { ${concatStringsSep ", " networking.access.cidrForNetwork.local.v4} }"
        (mkIf networking.enableIPv6
          "ip6 saddr { ${concatStringsSep ", " networking.access.cidrForNetwork.local.v6} }"
        )
      ];
    };
  };

  config._module.args.access = let
    systemFor = hostName: inputs.self.nixosConfigurations.${hostName}.config;
    systemForOrNull = hostName: inputs.self.nixosConfigurations.${hostName}.config or null;
  in {
    systemFor = hostName: if hostName == config.networking.hostName
      then config
      else systemFor hostName;
    systemForOrNull = hostName: if hostName == config.networking.hostName
      then config
      else systemForOrNull hostName;
  };
}
