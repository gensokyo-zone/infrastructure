{inputs, ...}: {
  config,
  options,
  ...
}: let
  hasConfigLib = options ? lib;
  gensokyo-zone = {
    inherit inputs;
    inherit (inputs.self.lib) tree meta lib;
  };
in {
  config = {
    ${
      if hasConfigLib
      then "lib"
      else null
    } = {
      inherit gensokyo-zone;
    };
    _module.args = {
      gensokyo-zone =
        if hasConfigLib
        then config.lib.gensokyo-zone
        else gensokyo-zone;
    };
  };
}
