{
  name,
  config,
  lib,
  inputs,
  ...
}: let
  inherit (inputs.self.lib.lib) domain;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkOptionDefault;
in {
  options.ci = with lib.types; {
    enable =
      mkEnableOption "build via CI"
      // {
        default = config.type == "NixOS";
      };
    allowFailure = mkOption {
      type = bool;
      default = false;
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
          inherit (inputs.self.legacyPackages.${config.system}.deploy-rs) activate;
        in
          activate.nixos nixos;
      };
    };
  };
}
