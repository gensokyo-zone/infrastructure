final: prev: let
  inherit (final) lib;
  # freeipa and its dep lesscpy broken currently...
  python3Packages = prev.lesscpy.pythonModule.pythonOnHostForHost.pkgs or final.python3Packages;
  #python3Packages'build = prev.lesscpy.pythonModule.pythonOnBuildForHost.pkgs or final.buildPackages.python3Packages;
  python3Packages'build = python3Packages;
  overrideSetuptools80 = old: {
    python3Packages = old.python3Packages or python3Packages // {
      setuptools = python3Packages'build.setuptools_80;
      distutils = python3Packages'build.distutils_80;
    };
  };
in {
  krb5-ldap = final.krb5.override {
    withLdap = true;
  };

  freeipa = prev.freeipa.override overrideSetuptools80;
  lesscpy = prev.lesscpy.override overrideSetuptools80;
}
