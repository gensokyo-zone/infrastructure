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
    accept-flake-config = true;
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
    };
  };

  channels = {
    nixfiles.path = ../.;
    nixpkgs.path = "${channels.nixfiles.inputs.nixpkgs}";
  };

  jobs.flake-update = {
    tasks.flake-build.inputs = with channels.cipkgs;
      ci.command {
        name = "flake-update-build";
        allowSubstitutes = false;
        cache = {
          enable = false;
        };
        displayName = "flake update build";
        environment = ["CACHIX_SIGNING_KEY" "GITHUB_REF"];
        command = let
          filteredHosts = [ "hakurei" "reimu" "aya" "tei" "litterbox" "mediabox" ];
          gcBetweenHosts = false;
          nodeBuildString = concatMapStringsSep " && " (node: "nix build -Lf . nixosConfigurations.${node}.config.system.build.toplevel -o result-${node}" + optionalString gcBetweenHosts " && nix-collect-garbage -d") filteredHosts;
          hostPath = builtins.getEnv "PATH";
        in ''
          # ${toString builtins.currentTime}
          export PATH="${hostPath}:$PATH"
          export NIX_CONFIG="$(printf '%s\naccept-flake-config = true\n' "''${NIX_CONFIG-}")"
          nix flake update

          if git status --porcelain | grep -qF flake.lock; then
            git -P diff flake.lock
            echo "checking that nodes still build..." >&2
            if ${nodeBuildString}; then
              if [[ -n $CACHIX_SIGNING_KEY ]]; then
                cachix push gensokyo-infrastructure result*/ &
                CACHIX_PUSH=$!
              fi
              git add flake.lock
              export GIT_{COMMITTER,AUTHOR}_EMAIL=github@kittywit.ch
              export GIT_{COMMITTER,AUTHOR}_NAME="flake cron job"
              git commit --message="ci: flake update"
              if [[ $GITHUB_REF = refs/heads/${gitBranch} ]]; then
                git push origin HEAD:${gitBranch}
              fi

              wait ''${CACHIX_PUSH-}
            fi
          else
            echo "no source changes" >&2
          fi
        '';
        impure = true;
      };
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
