{inputs, ...}: {
  lib,
  osConfig,
  ...
}: let
  inherit (inputs.self.lib) meta;
  inherit (lib.modules) mkIf;
in {
  imports = [
    meta.modules.extern.misc.args
  ];

  config = {
    lib.gensokyo-zone = mkIf (osConfig ? lib.gensokyo-zone) {
      os = osConfig.lib.gensokyo-zone;
    };
  };
}
