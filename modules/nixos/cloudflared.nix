{ pkgs, config, utils, lib, ... }: let
  inherit (lib.attrsets) mapAttrsToList mapAttrs' nameValuePair filterAttrsRecursive;
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkIf mkMerge mkForce;
  inherit (lib.options) mkOption mkEnableOption;
  cfg = config.services.cloudflared;
  settingsFormat = pkgs.formats.json { };
in {
  options.services.cloudflared = with lib.types; {
    tunnels = let
      tunnelModule = { config, ... }: {
        options = {
          extraTunnel = {
            enable = mkEnableOption "extra tunnels" // {
              default = config.extraTunnel.ingress != { };
            };
            ingress = mkOption {
              inherit (settingsFormat) type;
              default = { };
            };
          };
        };
      };
    in mkOption {
      type = attrsOf (submodule tunnelModule);
    };
  };
  config.systemd.services = let
    filterConfig = filterAttrsRecursive (_: v: ! builtins.elem v [ null [ ] { } ]);
    mapIngress = hostname: ingress: {
      inherit hostname;
    } // filterConfig (filterConfig ingress);
  in mkIf cfg.enable (mapAttrs' (uuid: tunnel: let
    RuntimeDirectory = "cloudflared-tunnel-${uuid}";
    configPath = "/run/${RuntimeDirectory}/config.yml";
    settings = {
      tunnel = uuid;
      credentials-file = tunnel.credentialsFile;
      ingress = mapAttrsToList mapIngress tunnel.ingress
      ++ mapAttrsToList mapIngress tunnel.extraTunnel.ingress
      ++ singleton { service = tunnel.default; };
    };
  in nameValuePair "cloudflared-tunnel-${uuid}" (mkMerge [
    {
      after = mkIf config.services.tailscale.enable [ "tailscale-autoconnect.service" ];
      serviceConfig = {
        RestartSec = 10;
      };
    }
    (mkIf tunnel.extraTunnel.enable {
      serviceConfig = {
        inherit RuntimeDirectory;
        ExecStart = mkForce [
          "${cfg.package}/bin/cloudflared tunnel --config=${configPath} --no-autoupdate run"
        ];
        ExecStartPre = [
          (pkgs.writeShellScript "cloudflared-tunnel-${uuid}-prepare" ''
            ${utils.genJqSecretsReplacementSnippet settings configPath}
          '')
        ];
      };
    })
  ])) cfg.tunnels);
}
