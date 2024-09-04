{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge mkDefault;
  cfg = config.services.vouch-proxy;
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
  };
}
