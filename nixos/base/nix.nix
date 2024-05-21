{
  config,
  options,
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostDefault;
  inherit (lib.modules) mkIf mkDefault;
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.trivial) importJSON;
  hasSops = options ? sops;
in {
  config = {
    boot.loader = {
      grub.configurationLimit = 8;
      systemd-boot.configurationLimit = 8;
    };

    nix = {
      registry = let
        lock = importJSON ../../flake.lock;
        mapFlake = name: let
          node = lock.nodes.${name};
        in
          {
            inherit (node.original) type;
            inherit (node.locked) lastModified rev narHash;
          }
          // optionalAttrs (node.original.type == "github") {
            inherit (node.original) repo owner;
          };
      in {
        nixpkgs.to = mapFlake "nixpkgs";
        arc.to = mapFlake "arcexprs";
        ci = {
          to = {
            inherit (lock.nodes.ci.original) type owner repo;
          };
          exact = false;
        };
      };
      settings = {
        allowed-users = ["@nixbuilder"];
        experimental-features = lib.optional (lib.versionAtLeast config.nix.package.version "2.4") "nix-command flakes";
        substituters = [
          "https://gensokyo-infrastructure.cachix.org"
          "https://arc.cachix.org"
          "https://kittywitch.cachix.org"
          "https://nix-community.cachix.org"
        ];
        trusted-public-keys = [
          "gensokyo-infrastructure.cachix.org-1:CY6ChfQ8KTUdwWoMbo8ZWr2QCLMXUQspHAxywnS2FyI="
          "arc.cachix.org-1:DZmhclLkB6UO0rc0rBzNpwFbbaeLfyn+fYccuAy7YVY="
          "kittywitch.cachix.org-1:KIzX/G5cuPw5WgrXad6UnrRZ8UDr7jhXzRTK/lmqyK0="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "ryantrinkle.com-1:JJiAKaRv9mWgpVAz8dwewnZe0AzzEAzPkagE9SP5NWI="
        ];
        trusted-users = ["root" "@wheel"];
      };
      extraOptions = mkIf hasSops ''
        !include ${config.sops.secrets.github-access-token-public.path}
      '';
      gc = {
        automatic = mkDefault true;
        dates = mkDefault "Mon 02:45";
        options = mkDefault "--delete-older-than 12d";
      };
      optimise = {
        automatic = mkAlmostDefault true;
        dates = mkDefault ["03:25"];
      };
    };
    ${
      if hasSops
      then "sops"
      else null
    }.secrets.github-access-token-public = {
      sopsFile = mkDefault ../secrets/nix.yaml;
      group = mkDefault "users";
      mode = mkDefault "0640";
    };
  };
}
