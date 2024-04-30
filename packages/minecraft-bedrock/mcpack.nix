{ stdenvNoCC, unzip, writeText }: stdenvNoCC.mkDerivation {
  name = "unzip-mcpack";
  propagatedBuildInputs = [ unzip ];
  dontUnpack = true;
  setupHook = writeText "mcpack-setup-hook.sh" ''
    unpackCmdHooks+=(_tryUnzipMcpack)
    _tryUnzipMcpack() {
      if ! [[ "$curSrc" =~ \.mcpack$ ]]; then return 1; fi

      LANG=en_US.UTF-8 unzip -qq "$curSrc"
    }
  '';
}
