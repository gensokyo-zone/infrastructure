{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkMerge mkDefault;
  inherit (lib.strings) removePrefix splitString concatStringsSep;
  inherit (lib.lists) head optional;
  cfg = config.security.acme;
  mkHash = with builtins; val: substring 0 20 (hashString "sha256" val);
  mkAccountHash = {
    server ? null,
    keyType,
    email,
  }:
    mkHash "${toString server} ${keyType} ${email}";
  mkHost = server: head (splitString "/" (removePrefix "https://" server));
  mkAccountDir = {
    server ? null,
    email,
    keyType,
  }:
    concatStringsSep "/" ([
        accountDirRoot
        (mkAccountHash {inherit server email keyType;})
      ]
      ++ optional (server != null) (
        mkHost server
      )
      ++ [
        cfg.defaults.email
      ]);
  accountDirRoot = "/var/lib/acme/.lego/accounts";
  addr = concatStringsSep "@" ["gensokyo" "arcn.mx"];
in {
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = mkDefault addr;
      server = mkDefault "https://acme-v02.api.letsencrypt.org/directory";
      keyType = mkDefault "ec384";
      dnsProvider = mkDefault "cloudflare";
      credentialFiles = {
        CLOUDFLARE_EMAIL_FILE = config.sops.secrets.acme_cloudflare_email.path;
        CLOUDFLARE_DNS_API_TOKEN_FILE = config.sops.secrets.acme_cloudflare_token.path;
      };
    };
  };
  sops.secrets = let
    accountDir = mkAccountDir {inherit (cfg.defaults) server email keyType;};
    acmeSecret = {
      sopsFile = mkDefault ./secrets/acme.yaml;
      owner = "acme";
      group = "nginx";
    };
  in {
    acme_account_key = mkMerge [
      acmeSecret
      {
        path = accountDir + "/keys/${cfg.defaults.email}.key";
      }
    ];
    acme_cloudflare_email = acmeSecret;
    acme_cloudflare_token = acmeSecret;
  };
  systemd.services = let
    after = [ "systemd-tmpfiles-resetup.service" ];
  in {
    acme-fixperms = {
      inherit after;
    };
    acme-lockfiles = {
      inherit after;
    };
  };
}
