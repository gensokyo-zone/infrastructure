{config, lib, inputs, ...}: let
  inherit (inputs.self.lib.lib) userIs mkAlmostOptionDefault;
  inherit (lib.modules) mkMerge mkDefault;
  inherit (lib.attrsets) mapAttrs filterAttrs;
  ldapUsers = filterAttrs (_: userIs "peeps") config.users.users;
  ldapGroups = filterAttrs (_: group: group.gid != null && group.gid >= 8000 && group.gid < 8256) config.users.groups;
  management = {
    users = mapAttrs (name: user: {
      user.name = mkAlmostOptionDefault name;
      samba = {
        enable = mkDefault true;
        sync.enable = mkDefault true;
        accountFlags = {
          noPasswordExpiry = mkDefault true;
        };
      };
    }) ldapUsers;
    groups = mapAttrs (name: group: {
      group.name = mkAlmostOptionDefault name;
      samba.enable = mkDefault true;
    }) ldapGroups;
  };
in {
  config.users.ldap = {
    management = mkMerge [ management {
      users = {
        guest.user.enable = true;
        admin = {
          user.enable = true;
          samba.enable = true;
        };
        opl = {
          user.enable = true;
          samba = {
            enable = true;
            #sync.enable = true;
            accountFlags = {
              noPasswordExpiry = mkDefault true;
              normalUser = true;
            };
          };
          object.settings.settings = {
            sambaNTPassword = "F7C2C5D78C24EACB73550B02BF5888E3";
            sambaLMPassword = "A5C96CDE7660B20BAAD3B435B51404EE";
          };
        };
      };
      groups = {
        nogroup = {
          group.enable = true;
          samba.enable = true;
        };
        guest = {
          samba = {
            enable = true;
            groupType = 4;
            sid = "S-1-5-32-546";
          };
        };
        admin = {
          group.enable = true;
          samba.enable = true;
        };
        kyuuto-peeps = {
          group.enable = true;
          samba.enable = true;
        };
        kyuuto = {
          group.enable = true;
          samba.enable = true;
        };
        peeps = {
          group.enable = true;
          samba.enable = true;
        };
        admins = {
          samba = {
            enable = true;
            #sync.enable = true;
            groupType = 4;
            sid = "S-1-5-32-544";
          };
        };
        smb = {
          name = "Default SMB Group";
          samba = {
            #sync.enable = true;
            groupType = 4;
            sid = "S-1-5-32-545";
          };
        };
      };
    } ];
  };
}
