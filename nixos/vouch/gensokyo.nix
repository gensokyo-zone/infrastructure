{
  config,
  meta,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (config.networking) domain;
  cfg = config.services.vouch-proxy;
  sopsFile = mkDefault ../secrets/vouch.yaml;
  enableKeycloak = true;
in {
  imports = [meta.nixos.vouch.default];
  services.vouch-proxy = {
    domain = mkDefault "login.${domain}";
    authUrl = mkIf enableKeycloak (
      mkDefault "https://sso.${domain}/realms/${domain}"
    );
    enableSettingsSecrets = true;
    extraSettings = {
      oauth.client_secret._secret = config.sops.secrets.vouch-client-secret.path;
      vouch.jwt.secret._secret = config.sops.secrets.vouch-jwt.path;
    };
  };

  sops.secrets = {
    vouch-jwt = {
      inherit sopsFile;
      owner = cfg.user;
    };
    vouch-client-secret = {
      inherit sopsFile;
      owner = cfg.user;
    };
  };
}
