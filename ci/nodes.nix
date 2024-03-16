{
  lib,
  config,
  channels,
  env,
  ...
}:
with lib; {
  name = "nodes";

  nixpkgs.args.localSystem = "x86_64-linux";
  nixpkgs.args.config.checkMetaRecursively = false;

  ci = {
    version = "v0.7";
    gh-actions = {
      enable = true;
    };
  };
  channels.nixfiles.path = ../.;

  nix.config = {
    extra-platforms = ["aarch64-linux" "armv6l-linux" "armv7l-linux"];
    #extra-sandbox-paths = with channels.cipkgs; map (package: builtins.unsafeDiscardStringContext "${package}?") [bash qemu "/run/binfmt"];
  };

  jobs = let
    enabledHosts = ["hakurei" "reimu" "aya" "tei" "litterbox" "keycloak" "mediabox" "ct"];
  in
    mapAttrs' (k: nameValuePair "${k}") (genAttrs enabledHosts (host: {
      tasks.${host}.inputs = channels.nixfiles.nixosConfigurations.${host}.config.system.build.toplevel;
    }));

  ci.gh-actions.checkoutOptions.submodules = false;
  cache.cachix.arc = {
    enable = true;
    publicKey = "arc.cachix.org-1:DZmhclLkB6UO0rc0rBzNpwFbbaeLfyn+fYccuAy7YVY=";
  };
  cache.cachix.gensokyo-infrastructure = {
    enable = true;
    publicKey = "gensokyo-infrastructure.cachix.org-1:CY6ChfQ8KTUdwWoMbo8ZWr2QCLMXUQspHAxywnS2FyI=";
    signingKey = "mewp";
  };
}
