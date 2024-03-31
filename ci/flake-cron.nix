{
  lib,
  channels,
  config,
  ...
}:
with lib; let
  gitBranch = "main";
in {
  name = "flake-update";

  nixpkgs.args.localSystem = "x86_64-linux";

  ci = {
    version = "v0.7";
    gh-actions = {
      enable = true;
    };
  };

  gh-actions.env.CACHIX_SIGNING_KEY = "\${{ secrets.CACHIX_SIGNING_KEY }}";

  nix.config = {
    extra-platforms = ["aarch64-linux" "armv6l-linux" "armv7l-linux"];
    #extra-sandbox-paths = with channels.cipkgs; map (package: builtins.unsafeDiscardStringContext "${package}?") [bash qemu "/run/binfmt"];
  };

  gh-actions = {
    on = let
      paths = [
        "default.nix" # sourceCache
        "ci/flake-cron.nix"
        config.ci.gh-actions.path
      ];
    in {
      push = {
        inherit paths;
      };
      pull_request = {
        inherit paths;
      };
      schedule = [
        {
          cron = "0 0 * * *";
        }
      ];
      workflow_dispatch = {};
    };
    jobs.flake-update = {
      # TODO: split this up into two phases, then push at the end so other CI tests can run first
      step.flake-update = {
        name = "flake update build";
        order = 500;
        run = "nix run .#nf-update";
        env = {
          CACHIX_SIGNING_KEY = "\${{ secrets.CACHIX_SIGNING_KEY }}";
          NF_UPDATE_GIT_COMMIT = "1";
          NF_UPDATE_CACHIX_PUSH = "1";
          NF_CONFIG_ROOT = "\${{ github.workspace }}";
        };
      };
    };
  };

  channels = {
    nixfiles.path = ../.;
    nixpkgs.path = "${channels.nixfiles.inputs.nixpkgs}";
  };

  jobs.flake-update = {
  };

  ci.gh-actions.checkoutOptions = {
    submodules = false;
    fetch-depth = 0;
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
