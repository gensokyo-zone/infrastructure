{
  config,
  gensokyo-zone,
  lib,
  pkgs,
  ...
}: {
  services.nginx.virtualHosts.gensokyoZone = {
    serverName = config.networking.domain;
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
    };
  };
}
