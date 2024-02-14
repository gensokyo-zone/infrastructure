
{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge mkDefault;
  inherit (lib.lists) optionals;
  inherit (config.networking.access) cidrForNetwork;
  inherit (config) kyuuto;
  cfg = config.services.samba;
  localAddrs = cidrForNetwork.loopback.all ++ cidrForNetwork.local.all
    ++ optionals config.services.tailscale.enable cidrForNetwork.tail.all;
  kyuuto-media = {
    path = kyuuto.mountDir;
    comment = "Kyuuto Media";
    writeable = true;
    public = false;
    "valid users" = [ "@kyuuto-peeps" ];
    "acl group control" = true;
    "create mask" = "0664";
    "force directory mode" = "3000";
    "directory mask" = "7775";
  };
in {
  services.samba = {
    usershare = {
      enable = mkDefault true;
      path = mkDefault (kyuuto.mountDir + "/usershares");
    };
    shares = mkIf cfg.enable {
      kyuuto-transfer = {
        comment = "Kyuuto Media Transfer Area";
        path = kyuuto.transferDir;
        writeable = true;
        browseable = true;
        public = true;
        "valid users" = mkMerge [
          (mkIf cfg.guest.enable [ cfg.guest.user ])
          [ "@peeps" ]
        ];
        #"guest only" = true;
        "hosts allow" = localAddrs;
        "acl group control" = true;
        "create mask" = "0664";
        "force directory mode" = "3000";
        "directory mask" = "7775";
      };
      kyuuto-library-access = {
        path = kyuuto.libraryDir;
        comment = "Kyuuto Library Access";
        writeable = false;
        browseable = true;
        public = true;
        "valid users" = mkMerge [
          (mkIf cfg.guest.enable [ cfg.guest.user ])
          [ "@kyuuto-peeps" ]
        ];
        "hosts allow" = localAddrs;
      };
      kyuuto-media = mkMerge [
        kyuuto-media
        {
          browseable = true;
          "hosts allow" = localAddrs;
        }
      ];
      kyuuto-media-global = mkMerge [
        kyuuto-media
        {
          browseable = false;
        }
      ];
      shared = {
        path = kyuuto.shareDir;
        comment = "Shared Data";
        writeable = true;
        public = false;
        browseable = false;
        "valid users" = [ "@peeps" ];
        "create mask" = "0775";
        "force file mode" = "3010";
        "force directory mode" = "3000";
        "directory mask" = "7775";
      };
      ${cfg.usershare.templateShare} = mkIf cfg.usershare.enable {
        writeable = true;
        browseable = true;
        public = false;
        "valid users" = [ "@peeps" ];
        "create mask" = "0664";
        "force directory mode" = "5000";
        "directory mask" = "7775";
      };
    };
  };

  # give guest users proper access to the transfer share
  users.users.guest.extraGroups = [ "kyuuto" ];
}
