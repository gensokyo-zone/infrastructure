{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge mkDefault;
  inherit (config.networking.access) cidrForNetwork;
  inherit (config) kyuuto;
  cfg = config.services.samba;
  guestUsers = mkIf cfg.guest.enable [cfg.guest.user];
  kyuuto-media = {
    "create mask" = "0664";
    "force directory mode" = "3000";
    "directory mask" = "7775";
  };
  kyuuto-library =
    kyuuto-media
    // {
      "acl group control" = true;
    };
in {
  services.samba = {
    usershare = {
      enable = mkDefault true;
      path = mkDefault (kyuuto.mountDir + "/usershares");
    };
    shares' = {
      kyuuto-transfer = {
        comment = "Kyuuto Media Transfer Area";
        path = kyuuto.transferDir;
        writeable = true;
        browseable = true;
        public = true;
        "valid users" = mkMerge [
          guestUsers
          ["@peeps"]
        ];
        #"guest only" = true;
        "hosts allow" = cidrForNetwork.allLocal.all;
        "acl group control" = true;
        "create mask" = "0664";
        "force directory mode" = "3000";
        "directory mask" = "7775";
      };
      kyuuto-library = mkMerge [
        kyuuto-library
        {
          path = kyuuto.libraryDir;
          comment = "Kyuuto Library";
          writeable = false;
          browseable = true;
          public = true;
          "valid users" = mkMerge [
            guestUsers
            ["@kyuuto-peeps"]
          ];
          "read list" = guestUsers;
          "write list" = ["@kyuuto-peeps"];
          "hosts allow" = cidrForNetwork.allLocal.all;
        }
      ];
      kyuuto-library-net = mkMerge [
        kyuuto-library
        {
          path = kyuuto.libraryDir;
          comment = "Kyuuto Library Access";
          writeable = true;
          public = false;
          browseable = false;
          "valid users" = ["@kyuuto-peeps"];
        }
      ];
      kyuuto-media = mkMerge [
        kyuuto-media
        {
          path = kyuuto.mountDir;
          comment = "Kyuuto Media";
          writeable = true;
          public = false;
          browseable = false;
          "valid users" = ["@kyuuto-peeps"];
        }
      ];
      shared = {
        path = kyuuto.shareDir;
        comment = "Shared Data";
        writeable = true;
        public = false;
        browseable = false;
        "valid users" = ["@peeps"];
        "create mask" = "0775";
        "force create mode" = "0010";
        "force directory mode" = "2000";
        "directory mask" = "7775";
      };
      ${cfg.usershare.templateShare} = mkIf cfg.usershare.enable {
        writeable = true;
        browseable = true;
        public = false;
        "valid users" = ["@peeps"];
        "create mask" = "0664";
        "force directory mode" = "5000";
        "directory mask" = "7775";
      };
    };
  };

  # give guest users proper access to the transfer share
  users.users.guest.extraGroups = ["kyuuto"];
}
