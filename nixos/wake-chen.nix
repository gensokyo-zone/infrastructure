{
  config,
  pkgs,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (gensokyo-zone.lib) mapOptionDefaults;
  inherit (lib.meta) getExe;
  chen = gensokyo-zone.systems.chen.config;
  service = "wake-chen";
in {
  systemd.services.${service} = {
    path = [pkgs.wol];
    script = ''
      exec wol ${chen.network.networks.local.macAddress}
    '';
    environment = mapOptionDefaults {
      WOL_MAC_ADDRESS = chen.network.networks.local.macAddress;
    };
    serviceConfig =
      mapOptionDefaults {
        Type = "oneshot";
        RemainAfterExit = false;
      }
      // {
        ExecStart = [
          "${getExe pkgs.wol} $WOL_MAC_ADDRESS"
        ];
      };
  };
  services.systemd2mqtt.units = ["${service}.service"];
}
