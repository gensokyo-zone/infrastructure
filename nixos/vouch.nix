{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge mkDefault;
  cfg = config.services.vouch-proxy;
  sopsFile = mkDefault ./secrets/vouch.yaml;
  enableKeycloak = true;
  hassVouch = false;
in {
  services.vouch-proxy = {
    enable = mkDefault true;
    package = mkIf hassVouch (pkgs.vouch-proxy.overrideAttrs (old: {
      postPatch =
        ''
          sed -i handlers/login.go \
            -e 's/badStrings *=.*$/badStrings = []string{}/'
        ''
        + old.postPatch or "";
      doCheck = false;
    }));
    domain = mkDefault "login.${config.networking.domain}";
    authUrl = mkIf enableKeycloak (
      mkDefault "https://sso.${config.networking.domain}/realms/${config.networking.domain}"
    );
    settings = mkMerge [
      {
        vouch.listen = mkDefault "0.0.0.0";
        vouch.cookie.secure = mkDefault false;
      }
      (mkIf enableKeycloak {
        oauth = {
          auth_url = mkDefault "${cfg.authUrl}/protocol/openid-connect/auth";
          token_url = mkDefault "${cfg.authUrl}/protocol/openid-connect/token";
          user_info_url = mkDefault "${cfg.authUrl}/protocol/openid-connect/userinfo";
        };
      })
    ];
    enableSettingsSecrets = mkDefault true;
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
