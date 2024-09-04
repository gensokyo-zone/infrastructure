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
  distinctLocal = true;
  jwtSecret =
    if distinctLocal
    then "vouch-jwt-local"
    else "vouch-jwt";
in {
  imports = [meta.nixos.vouch.default];
  services.vouch-proxy = {
    # configure a secondary vouch instance for local clients, but don't use it by default
    domain = mkDefault "login.local.${domain}";
    authUrl = mkIf enableKeycloak (
      mkDefault "https://sso.local.${domain}/realms/${domain}"
    );
    settings.vouch.cookie = {
      domain = "local.${domain}";
      name = mkIf distinctLocal "VouchLocal";
    };
    enableSettingsSecrets = true;
    extraSettings = {
      oauth.client_secret._secret = config.sops.secrets.vouch-client-secret.path;
      vouch.jwt.secret._secret = config.sops.secrets.${jwtSecret}.path;
    };
  };

  sops.secrets = {
    ${jwtSecret} = {
      inherit sopsFile;
      owner = cfg.user;
    };
    vouch-client-secret = {
      inherit sopsFile;
      owner = cfg.user;
    };
  };
}
