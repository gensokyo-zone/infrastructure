{
  config,
  lib,
  inputs,
  ...
}: let
  inherit (inputs.self.lib.lib) mkAlmostOptionDefault mkAlmostDefault;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkDefault mkOptionDefault;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.trivial) warnIf;
  inherit (config.services) nginx;
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
  sslModule = { config, name, ... }: let
    cfg = config.ssl;
  in {
    options.ssl = with lib.types; {
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
        copyFromStreamServer = mkOption {
          type = nullOr str;
          default = null;
        };
      };
    };
    config = {
      ssl = {
        enable = mkOptionDefault (cfg.cert.name != null || cfg.cert.keyPath != null);
        forced = mkOptionDefault (cfg.force != false && cfg.force != "reject");
        cert = let
          mkCopyCert = copyCert: {
            name = mkDefault copyCert.name;
            keyPath = mkDefault copyCert.keyPath;
            path = mkDefault copyCert.path;
          };
          copyCertVhost = mkCopyCert nginx.virtualHosts.${cfg.cert.copyFromVhost}.ssl.cert;
          copyCertStreamServer = mkCopyCert nginx.stream.servers.${cfg.cert.copyFromStreamServer}.ssl.cert;
        in mkMerge [
          (mkIf (cfg.cert.copyFromStreamServer != null) copyCertStreamServer)
          (mkIf (cfg.cert.copyFromVhost != null) copyCertVhost)
        ];
      };
    };
  };
  hostModule = { config, name, ... }: let
    cfg = config.ssl;
    emitForce = cfg.forced && config.proxied.enabled;
  in {
    imports = [ sslModule ];
    options = with lib.types; {
      ssl = {
        cert = {
          enable = mkEnableOption "ssl cert via name.shortServer";
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
        cert = let
          certConfig.name = mkIf cfg.cert.enable (warnIf (config.name.shortServer == null) "ssl.cert.enable set but name.shortServer is null" (
            mkAlmostOptionDefault config.name.shortServer
          ));
        in certConfig;
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
  upstreamServerModule = { config, nixosConfig, ... }: let
    cfg = config.ssl;
  in {
    imports = [ sslModule ];
    config = {
      ssl.cert = let
        cert = nixosConfig.security.acme.certs.${cfg.cert.name};
      in {
        path = mkIf (cfg.cert.name != null) (mkAlmostDefault "${cert.directory}/fullchain.pem");
        keyPath = mkIf (cfg.cert.name != null) (mkAlmostDefault "${cert.directory}/key.pem");
      };
      #listen.ssl = mkIf cfg.enable { ssl = true; };
      extraConfig = mkMerge [
        (mkIf (cfg.cert.path != null) "ssl_certificate ${cfg.cert.path};")
        (mkIf (cfg.cert.keyPath != null) "ssl_certificate_key ${cfg.cert.keyPath};")
      ];
    };
  };
in {
  options.services.nginx = with lib.types; {
    virtualHosts = mkOption {
      type = attrsOf (submoduleWith {
        modules = [ hostModule ];
        shorthandOnlyDefinesConfig = true;
      });
    };
    stream.servers = mkOption {
      type = attrsOf (submoduleWith {
        modules = [ upstreamServerModule ];
        shorthandOnlyDefinesConfig = false;
      });
    };
  };
  config.systemd.services.nginx = let
    mapStreamServer = server: mkIf (server.enable && server.ssl.enable && server.ssl.cert.name != null) {
      wants = [ "acme-finished-${server.ssl.cert.name}.target" ];
      after = [ "acme-selfsigned-${server.ssl.cert.name}.service" ];
      before = [ "acme-${server.ssl.cert.name}.service" ];
    };
    streamServerCerts = mapAttrsToList (_: mapStreamServer) nginx.stream.servers;
  in mkIf nginx.enable (mkMerge streamServerCerts);
}
