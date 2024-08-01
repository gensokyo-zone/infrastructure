{
  config,
  gensokyo-zone,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.modules) mkMerge mkAfter;
  inherit (lib.strings) escapeRegex;
  inherit (gensokyo-zone.lib) domain;
in {
  services.nginx.virtualHosts.gensokyoZone = {
    serverName = domain;
    locations = {
      "/" = {
        root = gensokyo-zone.inputs.website.packages.${pkgs.system}.gensokyoZone;
      };
      "/docs" = {
        root = pkgs.linkFarm "genso-docs-wwwroot" [
          {
            name = "docs";
            path = gensokyo-zone.self.packages.${pkgs.system}.docs;
          }
        ];
      };
      "/.well-known/webfinger" = let
        # https://www.rfc-editor.org/rfc/rfc7033#section-3.1
        oidc = {
          subject = "acct:${acct}@${domain}";
          links = [
            {
              rel = "http://openid.net/specs/connect/1.0/issuer";
              href = "https://sso.${domain}/realms/${domain}";
            }
          ];
        };
        acct = "$webfinger_oidc_acct";
      in {
        headers.set.Access-Control-Allow-Origin = "*";
        extraConfig = mkMerge [
          ''
            set ${acct} "";
            if ($arg_resource ~* "^acct(%3A|:)([^%@]*)(%40|@)${escapeRegex domain}$") {
              set ${acct} $2;
              add_header "Content-Type" "application/jrd+json";
            }
            # whitelist responses for OIDC only
            #if ($arg_rel !~* "http.*openid\.net") {
            #  set ${acct} "";
            #}
            if (${acct} = "") {
              return 404;
            }
          ''
          (mkAfter "return 200 '${builtins.toJSON oidc}';")
        ];
      };
    };
  };
}
