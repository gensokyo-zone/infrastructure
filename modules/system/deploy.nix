{
  name,
  config,
  lib,
  inputs,
  ...
}: let
  inherit (lib.modules) mkIf mkOptionDefault;
in {
  options = let
    inherit (inputs.self.lib.lib) json;
    inherit (lib.types) nullOr;
    inherit (lib.options) mkOption;
  in {
    deploy = mkOption {
      type = nullOr json.types.attrs;
    };
  };
  config = {
    deploy = let
      nixos = config.built;
    in {
      sshUser = mkOptionDefault "root";
      user = mkOptionDefault "root";
      sshOpts = mkIf (config.type == "NixOS") (
        mkOptionDefault ["-p" "${builtins.toString (builtins.head nixos.config.services.openssh.ports)}"]
      );
      autoRollback = mkOptionDefault true;
      magicRollback = mkOptionDefault true;
      fastConnection = mkOptionDefault false;
      hostname = mkOptionDefault "${name}.local.gensokyo.zone";
      profiles.system = {
        user = "root";
        path = let
          inherit (inputs.self.legacyPackages.${config.system}.deploy-rs) activate;
        in
          activate.nixos nixos;
      };
    };
  };
}
