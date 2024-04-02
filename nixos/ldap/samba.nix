{config, lib, ...}: let
  inherit (lib.modules) mkDefault;
  inherit (config.users) ldap;
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
      };
      "Custom Samba User Modify" = {
        targetType = "user";
        rights = [ "write" ];
        attrs = smbAccountAttrs;
      };
      "Custom Samba User Admin" = {
        targetType = "user";
        rights = [ "write" ];
        attrs = smbAccountAttrs ++ [ "objectclass" ];
      };
      "Custom Samba Group Read" = {
        targetType = "user-group";
        attrs = [ "ipantsecurityidentifier" "gidnumber" ] ++ smbGroupAttrs;
      };
      "Custom Samba Group Modify" = {
        targetType = "user-group";
        rights = [ "write" ];
        attrs = smbGroupAttrs;
      };
      "Custom Samba Group Admin" = {
        targetType = "user-group";
        rights = [ "write" ];
        attrs = smbGroupAttrs ++ [ "objectclass" ];
      };
      "Custom Samba Domain Read" = {
        targetType = "samba-domain";
        attrs = [ "objectClass" ] ++ smbDomainAttrs;
      };
      "Custom Samba Domain Modify" = {
        targetType = "samba-domain";
        rights = [ "write" "add" ];
        attrs = smbDomainAttrs;
      };
      "Custom Samba Domain Admin" = {
        targetType = "domain";
        rights = [ "write" ];
        attrs = smbDomainAttrs ++ [ "objectclass" ];
      };
      "Custom Samba Realm Read" = {
        targetType = "domain";
        attrs = [ "objectClass" "ipaNTSecurityIdentifier" "ipaNTFlatName" "ipaNTDomainGUID" "ipaNTFallbackPrimaryGroup" ] ++ smbDomainAttrs;
      };
      "Custom Samba Realm Modify" = {
        targetType = "domain";
        rights = [ "write" ];
        attrs = smbDomainAttrs;
      };
      "Custom Samba Realm Admin" = {
        targetType = "domain";
        rights = [ "write" ];
        attrs = smbDomainAttrs ++ [ "objectclass" ];
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
    sysAccounts = {
      samba = {
        passwordFile = config.sops.secrets.ldap-samba-password.path;
      };
    };
    privileges = {
      "Samba smbd" = {
        permissions = [
          "Custom Samba User Read"
          "Custom Samba Group Read"
          "Custom Samba Domain Read"
          "Custom Samba Realm Read"
        ];
      };
      "Custom Management Admin" = {
        permissions = [
          "Custom Samba User Admin"
          "Custom Samba Group Admin"
          "Custom Samba Domain Admin"
          "Custom Samba Realm Admin"
          "Custom Samba User Modify"
          "Custom Samba Group Modify"
          "Custom Samba Domain Modify"
          "Custom Samba Realm Modify"
        ];
      };
    };
    roles = {
      "Samba smbd" = {
        privileges = [
          "Samba smbd"
        ];
        members = [
          "krbprincipalname=cifs/hakurei.${config.networking.domain}@${config.security.ipa.realm},${ldap.serviceDnSuffix}"
          ldap.management.sysAccounts.samba.object.dn
        ];
      };
    };
    objects = {
      "cn=${config.networking.domain},${ldap.domainDnSuffix}" = {
        objectClasses = [ "sambaDomain" ];
        settings = {
          sambaSID = ldap.samba.domainSID;
          sambaDomainName = "GENSOKYO";
        };
      };
    };
  };
  config.sops.secrets = let
    sopsFile = mkDefault ../secrets/ldap.yaml;
  in {
    ldap-samba-password = {
      inherit sopsFile;
    };
  };
}
