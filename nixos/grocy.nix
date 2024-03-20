{config, lib, ...}: let
  inherit (lib.modules) mkDefault;
in {
  config = {
    services.grocy = {
      enable = mkDefault true;
      hostName = "grocy";
      nginx.enableSSL = false;
      settings = {
        currency = mkDefault "CAD";
      };
    };
    services.nginx = let
      name.shortServer = mkDefault "grocy";
    in {
      virtualHosts = {
        grocy = {
          inherit name;
        };
      };
    };
  };
}
