final: prev: let
  inherit (final) lib;
in {
  cura-octoprint = final.cura.override {
    plugins = [ final.curaPlugins.octoprint ];
  };

  octoprint = let
    mapPlugin = python3Packages: _: plugin: plugin.override {
      inherit python3Packages;
      inherit (python3Packages) buildPlugin;
    };
    packageOverrides = python3Packages: python3Packages'prev: lib.mapAttrs (mapPlugin python3Packages) {
      inherit (final.octoprintPlugins) prometheus-exporter;
    };
    octoprint = prev.octoprint.override (old: {
      packageOverrides = lib.composeExtensions old.packageOverrides or (_: _: {}) packageOverrides;
    });
  in octoprint;

  octoprintPlugins = let
    pythonPackages = final.octoprint.python.pkgs;
    octoprintPlugins'overlay = final.callPackage (final.path + "/pkgs/applications/misc/octoprint/plugins.nix") { };
    octoprintPlugins'nixpkgs = octoprintPlugins'overlay pythonPackages pythonPackages;
    octoprintPlugins = prev.octoprintPlugins or octoprintPlugins'nixpkgs;
    callPackage = final.newScope {
      inherit (final.octoprintPlugins) buildPlugin;
    };
  in octoprintPlugins // {
    callPackage = prev.octoprintPlugins.callPackage or callPackage;

    prometheus-exporter = callPackage ../packages/octoprint/prometheus-exporter.nix { };
  };

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
