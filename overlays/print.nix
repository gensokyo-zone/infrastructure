final: prev: let
  inherit (final) lib;
in {
  cura-octoprint = final.cura.override {
    plugins = [final.curaPlugins.octoprint];
  };

  klipper-ender3v3se = final.callPackage ../packages/klipper.nix {};

  octoprint = let
    mapPlugin = python3Packages: _: plugin:
      plugin.override {
        inherit python3Packages;
        inherit (python3Packages) buildPlugin;
      };
    packageOverrides = python3Packages: python3Packages'prev:
      lib.mapAttrs (mapPlugin python3Packages) {
        inherit (final.octoprintPlugins) prometheus-exporter octorant queue octoklipper;
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
      octoklipper = let
        octoklipper = {
          fetchFromGitHub,
          python3Packages,
          buildPlugin,
        }:
          octoprintPlugins.octoklipper.overrideAttrs (old: rec {
            name = "${old.pname}-${version}";
            version = lib.warnIf (lib.versionAtLeast old.version "0.3.8.4") "octoklipper updated upstream" "0.3.9.5";
            src = fetchFromGitHub {
              inherit (old.src) owner repo;
              rev = version;
              sha256 = "sha256-Ctxg6jyrXIR9sQQDu/Tjo+6+pOuSKgdDTYbnOKlU5ak=";
            };
          });
      in
        callPackage octoklipper {};
    };

  niimprint = final.python3Packages.callPackage ../packages/niimprint.nix {};
}
