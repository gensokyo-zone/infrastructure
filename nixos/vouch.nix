{
  lib,
  config,
  ...
}: let
  inherit (lib) mkDefault;
  cfg = config.services.vouch-proxy;
in {
  services.vouch-proxy = {
    enable = mkDefault true;
    domain = mkDefault "login.${config.networking.domain}";
    settings = {
      vouch.cookie.secure = mkDefault false;
    };
    enableSettingsSecrets = mkDefault true;
    extraSettings = {
      oauth.client_secret._secret = config.sops.secrets.vouch-client-secret.path;
      vouch.jwt.secret._secret = config.sops.secrets.vouch-jwt.path;
    };
  };

  sops.secrets = {
    vouch-jwt.owner = cfg.user;
    vouch-client-secret.owner = cfg.user;
  };
}
