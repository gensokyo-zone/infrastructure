final: prev: let
  inherit (final) lib;
in {
  cura-octoprint = final.cura.override {
    plugins = [final.curaPlugins.octoprint];
  };

  klipper = prev.callPackage ../packages/klipper.nix {};

  octoprint = let
    mapPlugin = python3Packages: _: plugin:
      plugin.override {
        inherit python3Packages;
        inherit (python3Packages) buildPlugin;
      };
    packageOverrides = python3Packages: python3Packages'prev:
      lib.mapAttrs (mapPlugin python3Packages) {
        inherit (final.octoprintPlugins) prometheus-exporter octorant queue printtimegenius;
      };
    octoprint = prev.octoprint.override (old: {
      packageOverrides = lib.composeExtensions old.packageOverrides or (_: _: {}) packageOverrides;
    });
  in
    octoprint;

  octoprintPlugins = let
    pythonPackages = final.octoprint.python.pkgs;
    octoprintPlugins'overlay = final.callPackage (final.path + "/pkgs/applications/misc/octoprint/plugins.nix") {};
    octoprintPlugins'nixpkgs = octoprintPlugins'overlay pythonPackages pythonPackages;
    octoprintPlugins = prev.octoprintPlugins or octoprintPlugins'nixpkgs;
    callPackage = final.newScope {
      inherit (final.octoprintPlugins) buildPlugin;
    };
  in
    octoprintPlugins
    // {
      callPackage = prev.octoprintPlugins.callPackage or callPackage;

      prometheus-exporter = callPackage ../packages/octoprint/prometheus-exporter.nix {};
      octorant = callPackage ../packages/octoprint/octorant.nix {};
      queue = callPackage ../packages/octoprint/queue.nix {};
      printtimegenius = let
        printtimegenius = {
          fetchFromGitHub,
          python3Packages,
          buildPlugin,
        }:
          octoprintPlugins.printtimegenius.overrideAttrs (old: rec {
            version = lib.warnIf (lib.versionAtLeast old.version "2.3.2") "printtimegenius updated upstream" "2.3.3";
            src = fetchFromGitHub {
              inherit (old.src) owner repo;
              rev = version;
              sha256 = "sha256-hqm8RShCNpsVbrVXquat5VXqcVc7q5tn5+7Ipqmaw4U=";
            };
          });
      in
        callPackage printtimegenius {};
    };

  # XXX: build broken upstream ugh...
  curaengine = prev.curaengine.override {
    inherit (final.python311Packages) libarcus;
  };
  cura = prev.cura.override {
    python3 = final.python311;
  };
  curaPlugins = prev.curaPlugins.override {
    python3Packages = final.python311Packages;
  };
}
