final: prev: {
  cura-octoprint = final.cura.override {
    plugins = [ final.curaPlugins.octoprint ];
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
