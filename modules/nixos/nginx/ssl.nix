let
  sslModule = { config, nixosConfig, gensokyo-zone, lib, ... }: let
    inherit (lib.options) mkOption;
    inherit (lib.modules) mkIf mkMerge mkDefault mkOptionDefault;
    inherit (nixosConfig.services) nginx;
    cfg = config.ssl;
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
      proxy.ssl = {
        enabled = mkOption {
          type = bool;
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
  sslProxyModule = { config, lib, ... }: let
    inherit (lib.options) mkOption mkEnableOption;
    inherit (lib.modules) mkIf mkMerge mkAfter;
    inherit (config) proxy;
    cfg = proxy.ssl;
  in {
    options.proxy.ssl = with lib.types; {
      enable = mkOption {
        type = bool;
      };
      verify = mkEnableOption "proxy_ssl_verify";
      sni = mkEnableOption "proxy_ssl_server_name" // {
        default = cfg.host != null;
      };
      host = mkOption {
        type = nullOr str;
        default = null;
        example = "xvars.get.proxy_host";
        description = "proxy_ssl_name";
        # $upstream_last_server_name is commercial-only :<
      };
    };
    config = {
      extraConfig = mkIf (proxy.enable && cfg.enable) (mkMerge [
        (mkIf cfg.verify "proxy_ssl_verify on;")
        (mkIf cfg.sni "proxy_ssl_server_name on;")
        (mkIf (cfg.host != null) (mkAfter "proxy_ssl_name ${cfg.host};"))
      ]);
    };
  };
  streamServerModule = { config, nixosConfig, gensokyo-zone, lib, ... }: let
    inherit (gensokyo-zone.lib) mkAlmostDefault;
    inherit (lib.options) mkEnableOption;
    inherit (lib.modules) mkIf mkMerge mkOptionDefault;
    cfg = config.ssl;
  in {
    imports = [ sslModule sslProxyModule ];
    options = with lib.types; {
      ssl = {
        kTLS = mkEnableOption "kTLS support" // {
          default = true;
        };
      };
    };
    config = let
      inherit (config) proxy;
      cert = nixosConfig.security.acme.certs.${cfg.cert.name};
      conf.ssl.cert = {
        path = mkIf (cfg.cert.name != null) (mkAlmostDefault "${cert.directory}/fullchain.pem");
        keyPath = mkIf (cfg.cert.name != null) (mkAlmostDefault "${cert.directory}/key.pem");
      };
      conf.proxy.ssl.enable = mkOptionDefault false;
      #confSsl.listen.ssl = { ssl = true; };
      confSsl.extraConfig = mkMerge [
        (mkIf (cfg.cert.path != null) "ssl_certificate ${cfg.cert.path};")
        (mkIf (cfg.cert.keyPath != null) "ssl_certificate_key ${cfg.cert.keyPath};")
        (mkIf cfg.kTLS "ssl_conf_command Options KTLS;")
      ];
      confProxy.extraConfig = mkIf proxy.ssl.enable "proxy_ssl on;";
    in mkMerge [
      conf
      (mkIf cfg.enable confSsl)
      (mkIf proxy.enable confProxy)
    ];
  };
in {
  config,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkDefault mkOptionDefault;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.trivial) warnIf;
  inherit (lib.strings) hasPrefix;
  inherit (config.services) nginx;
  forceRedirectConfig = { virtualHost, xvars }: ''
    if (${xvars.get.scheme} = http) {
      return ${toString virtualHost.redirectCode} https://${xvars.get.host}$request_uri;
    }
  '';
  locationModule = { config, virtualHost, xvars, ... }: let
    cfg = config.ssl;
    emitForce = cfg.force && !virtualHost.ssl.forced;
  in {
    imports = [ sslProxyModule ];
    options.ssl = {
      force = mkEnableOption "redirect to SSL";
    };
    config = {
      proxy.ssl.enable = mkOptionDefault (hasPrefix "https://" config.proxyPass);
      xvars.enable = mkIf emitForce true;
      extraConfig = mkIf emitForce (forceRedirectConfig { inherit xvars virtualHost; });
    };
  };
  hostModule = { config, xvars, ... }: let
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
      kTLS = mkAlmostOptionDefault true;

      xvars.enable = mkIf emitForce true;
      extraConfig = mkIf emitForce (forceRedirectConfig { virtualHost = config; inherit xvars; });
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
        modules = [ streamServerModule ];
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
