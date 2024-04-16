{
  config,
  lib,
  gensokyo-zone,
  pkgs,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkOrder mkBefore mkOptionDefault;
  inherit (lib.lists) optionals;
  inherit (gensokyo-zone.lib) unmerged;
  cfg = config.gensokyo-zone.dns;
  dnsModule = {
    gensokyo-zone,
    nixosConfig,
    config,
    pkgs,
    ...
  }: let
    inherit (gensokyo-zone.lib) unmerged;
    inherit (nixosConfig.gensokyo-zone) access;
    inherit (nixosConfig.networking) enableIPv6;
    enabled = {
      resolved = nixosConfig.services.resolved.enable;
      avahiResolver = nixosConfig.services.avahi.enable && (nixosConfig.services.avahi.nssmdns4 || nixosConfig.services.avahi.nssmdns4);
      tailscale = access.tail.enabled;
    };
  in {
    options = with lib.types; {
      enable = mkEnableOption "dns settings";
      prioritise = mkOption {
        type = bool;
        description = "prioritize our resolver over systemd-resolved";
      };
      fixHostname = mkOption {
        type = bool;
        default = true;
        description = "work around https://github.com/NixOS/nixpkgs/issues/132646";
      };
      nameservers = mkOption {
        type = listOf str;
      };
      fallback = mkOption {
        type = nullOr (enum [ "cloudflare" "google" ]);
        default = "cloudflare";
      };
      fallbackNameservers = mkOption {
        type = listOf str;
        description = "set by config.fallback";
      };
      set = {
        resolvedSettings = mkOption {
          type = unmerged.type;
          default = {};
        };
        nssSettings = mkOption {
          type = unmerged.type;
          default = {};
        };
      };
    };
    config = {
      prioritise = mkMerge [
        (mkOptionDefault false)
        (mkIf (access.local.enable && (enabled.resolved || enabled.avahiResolver)) (mkAlmostOptionDefault true))
      ];
      nameservers = let
        inherit (gensokyo-zone.systems) utsuho hakurei;
      in mkMerge [
        (mkOptionDefault [ ])
        (mkIf access.local.enable [
          (mkIf enableIPv6 utsuho.config.access.address6ForNetwork.local)
          utsuho.config.access.address4ForNetwork.local
        ])
        # TODO: mirror or tunnel on hakurei or something .-.
        (mkIf (access.tail.enabled && false) [
          (mkIf enableIPv6 hakurei.config.access.address6ForNetwork.tail)
          hakurei.config.access.address4ForNetwork.tail
        ])
      ];
      fallbackNameservers = mkOptionDefault {
        cloudflare = [
          "1.1.1.1#cloudflare-dns.com"
          "1.0.0.1#cloudflare-dns.com"
        ];
        google = optionals enableIPv6 [
          "[2001:4860:4860::8888]#dns.google"
          "[2001:4860:4860::8844]#dns.google"
        ] ++ [
          "8.8.8.8#dns.google"
          "8.8.4.4#dns.google"
        ];
        ${toString null} = [ ];
      }.${toString config.fallback};
      set = {
        nssSettings = {
          hosts = mkMerge [
            (mkIf config.prioritise (mkOrder 475 ["dns"]))
            (mkIf (config.fixHostname && nixosConfig.services.resolved.enable) (mkOrder 450 ["files"]))
          ];
        };
        resolvedSettings = {
          # TODO: enable = mkIf (!resolved.enable) false;
          extraConfig = mkIf config.prioritise ''
            DNSStubListener=no
          '';
        };
      };
    };
  };
in {
  imports = [
    ./access.nix
  ];

  options.gensokyo-zone.dns = mkOption {
    type = lib.types.submoduleWith {
      modules = [dnsModule];
      specialArgs = {
        inherit gensokyo-zone pkgs;
        inherit (gensokyo-zone) inputs;
        nixosConfig = config;
      };
    };
    default = { };
  };

  config = {
    networking.nameservers = mkIf (cfg.enable && cfg.nameservers != [ ]) (mkMerge [
      (mkBefore cfg.nameservers)
      cfg.fallbackNameservers
    ]);
    services.resolved = mkIf cfg.enable (unmerged.merge cfg.set.resolvedSettings);
    system.nssDatabases = mkIf cfg.enable (unmerged.merge cfg.set.nssSettings);
    # TODO: networking.hosts? many served by dnsmasq are statically determined anyway...
    lib.gensokyo-zone.dns = {
      inherit cfg dnsModule;
    };
  };
}
