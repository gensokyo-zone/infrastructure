{inputs, ...}: {...}: let
  inherit (inputs.self.lib) meta;
in {
  imports = [
    meta.modules.extern.misc.args
  ];
}
