{config, lib, ...}: let
  inherit (lib.modules) mkDefault;
  inherit (config.users) ldap;
  inherit (ldap.management) permissions;
  adminPriv = "cn=Custom Management Admin,${ldap.privilegeDnSuffix}";
  smbPriv = "cn=Samba smbd,${ldap.privilegeDnSuffix}";
  smbRole = "cn=Samba smbd,${ldap.roleDnSuffix}";
  smbAccountAttrs = [ "sambasid" "sambapwdlastset" "sambaacctflags" "sambapasswordhistory" "sambantpassword" ];
  smbGroupAttrs = [ "sambasid" "sambagrouptype" ];
  smbDomainAttrs = [ "sambasid" "sambaRefuseMachinePwdChange" "sambaMinPwdLength" "sambaAlgorithmicRidBase" "sambaPwdHistoryLength" "sambaDomainName" "sambaMinPwdAge" "sambaMaxPwdAge" "sambaLockoutThreshold" "sambaForceLogoff" "sambaLogonToChgPwd" "sambaLockoutObservationWindow" "sambaNextUserRid" "sambaLockoutDuration" ];
in {
  config.users.ldap.management = {
    enable = mkDefault true;
    permissions = {
      "Custom Samba User Read" = {
        targetType = "user";
        attrs = [ "ipanthash" "ipanthomedirectory" "ipanthomedirectorydrive" "ipantlogonscript" "ipantprofilepath" "ipantsecurityidentifier" ] ++ smbAccountAttrs;
        members = [ smbPriv ];
      };
      "Custom Samba User Modify" = {
        targetType = "user";
        rights = [ "write" ];
        attrs = smbAccountAttrs;
        members = permissions."Custom Samba User Admin".members;
      };
      "Custom Samba User Admin" = {
        targetType = "user";
        rights = [ "write" "add" ];
        attrs = [ "objectclass" ];
        members = [ adminPriv ];
      };
      "Custom Samba Group Read" = {
        targetType = "user-group";
        attrs = [ "ipantsecurityidentifier" "gidnumber" ] ++ smbGroupAttrs;
        members = [ smbPriv ];
      };
      "Custom Samba Group Modify" = {
        targetType = "user-group";
        rights = [ "write" ];
        attrs = smbGroupAttrs;
        members = permissions."Custom Samba Group Admin".members;
      };
      "Custom Samba Group Admin" = {
        targetType = "user-group";
        rights = [ "write" "add" ];
        attrs = [ "objectclass" ];
        members = [ adminPriv ];
      };
      "Custom Samba Domain Read" = {
        targetType = "samba-domain";
        attrs = [ "objectClass" ] ++ smbDomainAttrs;
        members = [ smbPriv ];
      };
      "Custom Samba Domain Modify" = {
        targetType = "samba-domain";
        rights = [ "write" ];
        attrs = smbDomainAttrs;
        members = permissions."Custom Samba Domain Admin".members;
      };
      "Custom Samba Domain Admin" = {
        targetType = "domain";
        rights = [ "write" "add" ];
        attrs = [ "objectclass" ];
        members = [ adminPriv ];
      };
      "Custom Samba Realm Read" = {
        targetType = "domain";
        attrs = [ "objectClass" "ipaNTSecurityIdentifier" "ipaNTFlatName" "ipaNTDomainGUID" "ipaNTFallbackPrimaryGroup" ] ++ smbDomainAttrs;
        members = [ smbPriv ];
      };
      "Custom Samba Realm Modify" = {
        targetType = "domain";
        rights = [ "write" ];
        attrs = smbDomainAttrs;
        members = permissions."Custom Samba Realm Admin".members;
      };
      "Custom Samba Realm Admin" = {
        targetType = "user-group";
        rights = [ "write" "add" ];
        attrs = [ "objectclass" ];
        members = [ adminPriv ];
      };
    };
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
          enable = true;
          #sync.enable = true;
          groupType = 4;
          sid = "S-1-5-32-545";
        };
      };
    };
    objects = {
      ${smbPriv} = {
        changeType = "add";
        settings = {
          objectClass = [ "top" "nestedgroup" "groupofnames" ];
          member = map config.lib.ldap.withBaseDn [
            "cn=Security Architect,${ldap.roleDnSuffix}"
            "uid=samba,${ldap.sysAccountDnSuffix}"
            smbRole
          ];
        };
      };
      ${smbRole} = {
        changeType = "add";
        settings = {
          objectClass = [ "top" "nestedgroup" "groupofnames" ];
          member = map config.lib.ldap.withBaseDn [
            "krbprincipalname=cifs/hakurei.${config.networking.domain}@${config.security.ipa.realm},${ldap.serviceDnSuffix}"
          ];
        };
      };
      "cn=${config.networking.domain},${ldap.domainDnSuffix}" = {
        objectClasses = [ "sambaDomain" ];
        settings = {
          sambaSID = ldap.samba.domainSID;
          sambaDomainName = "GENSOKYO";
        };
      };
    };
  };
}
