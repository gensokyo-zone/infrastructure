{
  lib,
  channels,
  config,
  ...
}: {
  nixpkgs.args = {
    localSystem = "x86_64-linux";
    config = {
      allowUnfree = true;
    };
  };

  ci = {
    version = "v0.7";
    gh-actions = {
      enable = true;
    };
  };

  /*nix.config = {
    extra-platforms = ["aarch64-linux" "armv6l-linux" "armv7l-linux"];
    #extra-sandbox-paths = with channels.cipkgs; map (package: builtins.unsafeDiscardStringContext "${package}?") [bash qemu "/run/binfmt"];
  };*/

  channels = {
    nixfiles.path = ../.;
    nixpkgs.path = "${channels.nixfiles.inputs.nixpkgs}";
  };

  ci.gh-actions.checkoutOptions = {
    submodules = false;
  };

  cache.cachix = {
    arc = {
      enable = true;
      publicKey = "arc.cachix.org-1:DZmhclLkB6UO0rc0rBzNpwFbbaeLfyn+fYccuAy7YVY=";
      signingKey = null;
    };
    gensokyo-infrastructure = {
      enable = true;
      publicKey = "gensokyo-infrastructure.cachix.org-1:CY6ChfQ8KTUdwWoMbo8ZWr2QCLMXUQspHAxywnS2FyI=";
      signingKey = "mewp";
    };
  };
}
