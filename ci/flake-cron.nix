{
  lib,
  channels,
  config,
  ...
}:
with lib; let
  pkgs = channels.nixpkgs;
in {
  imports = [ ./common.nix ];
  config = {
    name = "flake-update";

    gh-actions = {
      env.CACHIX_SIGNING_KEY = "\${{ secrets.CACHIX_SIGNING_KEY }}";
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
        step.flake-update = {
          name = "flake update build";
          order = 500;
          run = "nix run .#nf-update";
          env = {
            CACHIX_SIGNING_KEY = "\${{ secrets.CACHIX_SIGNING_KEY }}";
            NF_UPDATE_GIT_COMMIT = "";
            NF_UPDATE_CACHIX_PUSH = "1";
            NF_CONFIG_ROOT = "\${{ github.workspace }}";
          };
        };
        # we split this up into two phases so other CI tests can run in-between
        step.flake-commit = {
          name = "git push";
          order = 1500;
          run = "nix run .#nf-update";
          env = {
            NF_UPDATE_SKIP = "1";
            NF_UPDATE_GIT_COMMIT = "1";
            NF_CONFIG_ROOT = "\${{ github.workspace }}";
          };
        };
      };
    };

    jobs = {
      flake-update = { ... }: {
        imports = [ ./packages.nix ];
      };
      barcodebuddy-update = {
        ci.gh-actions.name = "barcodebuddy update check";
        tasks.check = let
          barcodebuddy-check = let
            lock = importJSON ../flake.lock;
            inherit (lock.nodes) barcodebuddy;
            inherit (barcodebuddy.original) ref;
            impure = toString builtins.currentTime or channels.nixfiles.inputs.sourceInfo.lastModified;
            outputHashAlgo = "sha256";
            outputHash = builtins.hashString outputHashAlgo "${ref}!${impure}\n";
          in pkgs.runCommand "barcodebuddy-check-${ref}" {
            inherit outputHash outputHashAlgo impure ref;
            outputHashMode = "flat";
            preferLocalBuild = true;
            allowSubstitutes = false;
            impureEnvVars = lib.fetchers.proxyImpureEnvVars ++ [ "NIX_CURL_FLAGS" ];
            nativeBuildInputs = with pkgs.buildPackages; [ curl jq ];
            inherit (barcodebuddy.original) owner repo;
            query = "sort_by(.tag_name) | [.[]|select(.prerelease==false and .draft==false)] | .[-1].tag_name";
            meta.displayName = "barcodebuddy ${ref} outdated";
          } ''
            BB_RELEASES=$(curl \
              --insecure \
              -fSsL \
              -H "X-GitHub-Api-Version: 2022-11-28" \
              "https://api.github.com/repos/$owner/$repo/releases"
            )
            BB_LATEST=$(jq -r "$query" - <<< "$BB_RELEASES")
            if [[ $BB_LATEST = $ref ]]; then
              echo "barcodebuddy-$ref up-to-date" >&2
            else
              echo "barcodebuddy-$ref out of date, found version $BB_LATEST" >&2
            fi
            printf '%s!%s\n' "$BB_LATEST" "$impure" > $out
          '';
        in {
          inputs = [ barcodebuddy-check ];
          cache.enable = false;
        };
      };
    };

    ci.gh-actions.checkoutOptions = {
      fetch-depth = 0;
    };
  };
}
