{
  config,
  lib,
  meta,
  ...
}:
with lib; {
  services.nginx.virtualHosts."cloud.${config.networking.domain}" = {
    locations = {
      "/".proxyPass = meta.tailnet.yukari.ppp 4 80 "nextcloud/";
    };
  };
}
