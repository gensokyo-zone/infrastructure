
{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (lib.lists) optionals;
  inherit (config.networking.access) cidrForNetwork;
  inherit (config) kyuuto;
  cfg = config.services.samba;
  localAddrs = cidrForNetwork.loopback.all ++ cidrForNetwork.local.all
    ++ optionals config.services.tailscale.enable cidrForNetwork.tail.all;
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
        #"guest only" = true;
        "hosts allow" = localAddrs;
        "acl group control" = true;
        "create mask" = "0664";
        "force directory mode" = "3000";
        "directory mask" = "7775";
      };
      kyuuto-access = {
        path = kyuuto.libraryDir;
        comment = "Kyuuto Media Access";
        writeable = false;
        browseable = true;
        public = true;
        "hosts allow" = localAddrs;
      };
      kyuuto-media = {
        path = kyuuto.mountDir;
        comment = "Kyuuto Media";
        writeable = true;
        browseable = true;
        public = false;
        "valid users" = [ "@kyuuto-peeps" ];
        "acl group control" = true;
        "create mask" = "0664";
        "force directory mode" = "3000";
        "directory mask" = "7775";
      };
    };
  };

  # give guest users proper access to the transfer share
  users.users.guest.extraGroups = [ "kyuuto" ];
}
