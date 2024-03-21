{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkDefault mkOptionDefault mkOverride;
  inherit (lib.trivial) warnIf;
  inherit (config.services.nginx) virtualHosts;
  mkAlmostOptionDefault = mkOverride 1250;
  forceRedirectConfig = virtualHost: ''
    if ($x_scheme = http) {
      return ${toString virtualHost.redirectCode} https://$x_forwarded_host$request_uri;
    }
  '';
  locationModule = { config, virtualHost, ... }: let
    cfg = config.ssl;
    emitForce = cfg.force && !virtualHost.ssl.forced;
  in {
    options.ssl = {
      force = mkEnableOption "redirect to SSL";
    };
    config = {
      proxied.xvars.enable = mkIf emitForce true;
      extraConfig = mkIf emitForce (forceRedirectConfig virtualHost);
    };
  };
  hostModule = { config, name, ... }: let
    cfg = config.ssl;
    emitForce = cfg.forced && config.proxied.enabled;
  in {
    options = with lib.types; {
      ssl = {
        enable = mkOption {
          type = bool;
        };
        force = mkOption {
          # TODO: "force-nonlocal"? exceptions for tailscale?
          type = enum [ false true "only" "reject" ];
          default = false;
        };
        forced = mkOption {
          type = bool;
          readOnly = true;
        };
        cert = {
          enable = mkEnableOption "ssl cert via name.shortServer";
          name = mkOption {
            type = nullOr str;
            default = null;
          };
          keyPath = mkOption {
            type = nullOr path;
            default = null;
          };
          path = mkOption {
            type = nullOr path;
            default = null;
          };
          copyFromVhost = mkOption {
            type = nullOr str;
            default = null;
          };
        };
      };
      locations = mkOption {
        type = attrsOf (submoduleWith {
          modules = [ locationModule ];
          shorthandOnlyDefinesConfig = true;
        });
      };
    };
    config = {
      ssl = {
        enable = mkOptionDefault (cfg.cert.name != null || cfg.cert.keyPath != null);
        forced = mkOptionDefault (cfg.force != false && cfg.force != "reject");
        cert = let
          certConfig.name = mkIf cfg.cert.enable (warnIf (config.name.shortServer == null) "ssl.cert.enable set but name.shortServer is null" (
            mkAlmostOptionDefault config.name.shortServer
          ));
          copyCert = virtualHosts.${cfg.cert.copyFromVhost}.ssl.cert;
          otherCertConfig = mkIf (cfg.cert.copyFromVhost != null) {
            name = mkDefault copyCert.name;
            keyPath = mkAlmostOptionDefault copyCert.keyPath;
            path = mkAlmostOptionDefault copyCert.path;
          };
        in mkMerge [
          certConfig
          otherCertConfig
        ];
      };
      addSSL = mkIf (cfg.enable && (cfg.force == false || emitForce)) (mkDefault true);
      forceSSL = mkIf (cfg.enable && cfg.force == true && !emitForce) (mkDefault true);
      onlySSL = mkIf (cfg.enable && cfg.force == "only" && !emitForce) (mkDefault true);
      rejectSSL = mkIf (cfg.force == "reject") (mkDefault true);
      useACMEHost = mkAlmostOptionDefault cfg.cert.name;
      sslCertificate = mkIf (cfg.cert.path != null) (mkAlmostOptionDefault cfg.cert.path);
      sslCertificateKey = mkIf (cfg.cert.keyPath != null) (mkAlmostOptionDefault cfg.cert.keyPath);

      proxied.xvars.enable = mkIf emitForce true;
      extraConfig = mkIf emitForce (forceRedirectConfig config);
    };
  };
in {
  options = with lib.types; {
    services.nginx.virtualHosts = mkOption {
      type = attrsOf (submoduleWith {
        modules = [ hostModule ];
        shorthandOnlyDefinesConfig = true;
      });
    };
  };
}
