{
  config,
  options,
  lib,
  inputs,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  hasSops = options ? sops;
in {
  config = {
    boot.loader = {
      grub.configurationLimit = 8;
      systemd-boot.configurationLimit = 8;
    };

    nix = {
      nixPath = [
        "nixpkgs=${inputs.nixpkgs}"
        "nur=${inputs.nur}"
        "arc=${inputs.arcexprs}"
        "ci=${inputs.ci}"
      ];
      registry = {
        nixpkgs.flake = inputs.nixpkgs;
        nur.flake = inputs.nur;
        arc.flake = inputs.arcexprs;
        ci.flake = inputs.ci;
      };
      settings = {
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
        auto-optimise-store = true;
        trusted-users = ["root" "@wheel"];
      };
      extraOptions = mkIf hasSops ''
        !include ${config.sops.secrets.github-access-token-public.path}
      '';
      gc = {
        automatic = mkDefault true;
        dates = mkDefault "weekly";
        options = mkDefault "--delete-older-than 7d";
      };
    };
    ${
      if hasSops
      then "sops"
      else null
    }.secrets.github-access-token-public = {
      sopsFile = mkDefault ../secrets/nix.yaml;
      group = mkDefault "users";
      mode = mkDefault "0644";
    };
  };
}
