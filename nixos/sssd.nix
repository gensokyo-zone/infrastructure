{ gensokyo-zone, access, config, lib, ... }: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.modules) mkIf mkBefore mkAfter mkDefault;
  inherit (lib.lists) tail;
  inherit (lib.strings) splitString concatStringsSep;
  cfg = config.services.sssd;
in {
  imports = [
    ./krb5.nix
  ];

  config = {
    services.sssd = {
      enable = (mkDefault true);
      gensokyo-zone = let
        serviceFragment = service: service;
        toService = service: hostname: let
          segments = splitString "." hostname;
        in concatStringsSep "." ([ (serviceFragment service) ] ++ tail segments);
        toFreeipa = toService "freeipa";
        tailName = access.getHostnameFor "hakurei" "tail";
        mkServers = serviceName: let
          system = access.systemForService serviceName;
          lanName = access.getHostnameFor system.name "lan";
          localName = access.getHostnameFor system.name "local";
          localToo = lanName != localName;
        in {
          servers = mkBefore [
            lanName
            (mkIf localToo localName)
          ];
          backups = mkAlmostOptionDefault (mkAfter [
            (toFreeipa lanName)
            (mkIf config.services.tailscale.enable (toFreeipa tailName))
          ]);
        };
      in {
        krb5.servers = mkServers "kerberos";
        ipa.servers = mkServers "freeipa";
        ldap = {
          uris = {
            backups = mkAlmostOptionDefault (mkAfter [
              (mkIf config.services.tailscale.enable (toService "ldap" tailName))
            ]);
          };
          bind.passwordFile = mkIf (cfg.gensokyo-zone.backend == "ldap") config.sops.secrets.gensokyo-zone-peep-passwords.path;
        };
      };
      environmentFile = mkIf (cfg.gensokyo-zone.enable && cfg.gensokyo-zone.backend == "ldap") (mkAlmostOptionDefault
        config.sops.secrets.gensokyo-zone-sssd-passwords.path
      );
    };

    sops.secrets = let
      sopsFile = mkDefault ./secrets/krb5.yaml;
    in mkIf (cfg.enable && cfg.gensokyo-zone.enable) {
      gensokyo-zone-krb5-peep-password = mkIf (cfg.gensokyo-zone.enable && cfg.gensokyo-zone.backend == "ldap") {
        inherit sopsFile;
      };
      # TODO: this shouldn't be needed, module is incomplete :(
      gensokyo-zone-sssd-passwords = mkIf (cfg.gensokyo-zone.enable && cfg.gensokyo-zone.backend == "ldap") {
        inherit sopsFile;
      };
    };
  };
}
