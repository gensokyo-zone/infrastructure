{ pkgs, config, lib, ... }: let
  inherit (lib.options) mkEnableOption mkPackageOption;
  inherit (lib.modules) mkIf;
  cfg = config.boot.binfmt.cross.aarch64;
in {
  options = {
    boot.binfmt.cross.aarch64 = {
      enable = mkEnableOption "qemu-aarch64" // {
        default = true;
      };
      package = mkPackageOption pkgs "qemu" { };
      armv7l = mkEnableOption "arm.cachix.org";
    };
  };

  config = {
    boot.binfmt = {
      emulatedSystems = mkIf cfg.enable [ "aarch64-linux" ];
      registrations.aarch64-linux = mkIf cfg.enable {
        interpreter = "${cfg.package}/bin/qemu-aarch64";
        wrapInterpreterInShell = false;
      };
    };

    nix.settings = mkIf cfg.armv7l {
      substituters = [ "https://arm.cachix.org/" ];
      trusted-public-keys = [ "arm.cachix.org-1:5BZ2kjoL1q6nWhlnrbAl+G7ThY7+HaBRD9PZzqZkbnM=" ];
    };
  };
}
