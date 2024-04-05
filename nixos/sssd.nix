{ gensokyo-zone, access, config, lib, ... }: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.modules) mkIf mkBefore mkAfter mkDefault;
  inherit (lib.strings) replaceStrings;
  cfg = config.services.sssd;
in {
  imports = [
    ./krb5.nix
  ];

  config = {
    services.sssd = {
      enable = (mkDefault true);
      gensokyo-zone = let
        toService = service: replaceStrings [ "idp." ] [ "${service}." ];
        toFreeipa = toService "freeipa";
        toLdap = toService "ldap";
        lanName = access.getHostnameFor "freeipa" "lan";
        localName = access.getHostnameFor "freeipa" "local";
        tailName = access.getHostnameFor "hakurei" "tail";
        localToo = lanName != localName;
        servers = mkBefore [
          lanName
          (mkIf localToo localName)
        ];
        backups = mkAlmostOptionDefault (mkAfter [
          (toFreeipa lanName)
          (mkIf config.services.tailscale.enable (toFreeipa tailName))
        ]);
      in {
        krb5.servers = {
          inherit servers backups;
        };
        ldap = {
          uris = {
            backups = mkAlmostOptionDefault (mkAfter [
              (mkIf config.services.tailscale.enable (toLdap tailName))
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
