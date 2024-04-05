{inputs, ...}: {
  config,
  options,
  ...
}: let
  hasConfigLib = options ? lib;
  gensokyo-zone = inputs.self.lib.gensokyo-zone // {};
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
