
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
        path = kyuuto.transferDir;
        writeable = true;
        browseable = true;
        public = true;
        "acl group control" = true;
        #"guest only" = true;
        comment = "Kyuuto Media Transfer Area";
        "hosts allow" = localAddrs;
      };
      kyuuto-access = {
        path = kyuuto.libraryDir;
        writeable = false;
        browseable = true;
        public = true;
        comment = "Kyuuto Media Access";
        "hosts allow" = localAddrs;
      };
      kyuuto-media = {
        path = kyuuto.mountDir;
        writeable = true;
        browseable = true;
        public = false;
        comment = "Kyuuto Media";
        "valid users" = [ "@kyuuto" ];
      };
    };
  };
}
