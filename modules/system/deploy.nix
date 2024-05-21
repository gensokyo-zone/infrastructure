{
  name,
  config,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (gensokyo-zone.lib) domain;
  inherit (lib.modules) mkIf mkOptionDefault;
in {
  options = let
    inherit (gensokyo-zone.lib) json;
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
      hostname = mkOptionDefault "${name}.local.${domain}";
      profiles.system = {
        user = "root";
        path = let
          inherit (gensokyo-zone.self.legacyPackages.${config.system}.deploy-rs) activate;
        in
          activate.nixos nixos;
      };
    };
  };
}
