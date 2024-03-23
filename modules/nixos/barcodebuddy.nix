{ config, lib, pkgs, ... }: let
  inherit (lib.options) mkOption mkEnableOption mkPackageOption;
  inherit (lib.modules) mkIf mkMerge mkAfter mkDefault mkOptionDefault mkOverride;
  inherit (lib.attrsets) mapAttrs mapAttrs' nameValuePair;
  inherit (lib.lists) isList imap0;
  inherit (lib.strings) concatStringsSep;
  mkAlmostOptionDefault = mkOverride 1250;
  mapOptionDefaults = mapAttrs (_: mkOptionDefault);
  cfg = config.services.barcodebuddy;
  toEnvName = key: "BBUDDY_" + key;
  toEnvValue = value:
    if value == true then "true"
    else if value == false then "false"
    else if isList value then concatStringsSep ";" (imap0 (i: v: "${toString i}=${toEnvValue v}") value)
    else toString value;
  toEnvPair = key: value: nameValuePair (toEnvName key) (toEnvValue value);
  toPhpEnvPair = key: value: nameValuePair (toEnvName key) ''"${toEnvValue value}"'';
in {
  options.services.barcodebuddy = with lib.types; {
    enable = mkEnableOption "Barcode Buddy";
    package = mkPackageOption pkgs "barcodebuddy" { };
    phpPackageUnwrapped = mkPackageOption pkgs "php83" { };
    hostName = mkOption {
      type = str;
    };
    dataDir = mkOption {
      type = path;
      default = "/var/lib/barcodebuddy";
    };
    databasePath = mkOption {
      type = path;
      default = "${cfg.dataDir}/barcodebuddy.db";
    };
    authDatabasePath = mkOption {
      type = path;
      default = "${cfg.dataDir}/users.db";
    };
    reverseProxy = {
      enable = mkEnableOption "reverse proxy";
      trustedAddresses = mkOption {
        type = listOf str;
        default = [ "127.0.0.1" "::1" ];
      };
    };
    screen = {
      enable = mkEnableOption "websocket server";
      websocketPort = mkOption {
        type = port;
        default = 47631;
      };
    };
    redis = {
      enable = mkEnableOption "redis cache";
      server = mkOption {
        type = nullOr str;
        default = null;
        description = "services.redis.servers";
      };
      ip = mkOption {
        type = str;
      };
      port = mkOption {
        type = port;
      };
      password = mkOption {
        type = nullOr str;
        default = null;
      };
      /* TODO: passwordFile = mkOption {
        type = nullOr path;
        default = null;
      };*/
    };
    settings = mkOption {
      type = attrsOf (oneOf [ str bool int (listOf str) ]);
      description = "https://github.com/Forceu/barcodebuddy/blob/master/config-dist.php";
    };
    nginxConfig = mkOption {
      type = lines;
    };
    nginxPhpConfig = mkOption {
      type = lines;
    };
  };

  config = let
    bbuddyConfig.services.barcodebuddy = {
      settings = let
        defaults = mapOptionDefaults {
          ${if cfg.screen.enable then "PORT_WEBSOCKET_SERVER" else null} = cfg.screen.websocketPort;
          SEARCH_ENGINE = "https://google.com/search?q=";
          ${if cfg.reverseProxy.enable then "TRUSTED_PROXIES" else null} = cfg.reverseProxy.trustedAddresses;
          DISABLE_AUTHENTICATION = false;
          DATABASE_PATH = cfg.databasePath;
          AUTHDB_PATH = cfg.authDatabasePath;
          CONFIG_PATH = "${pkgs.writeText "barcodebuddy.conf.php" ""}";
        };
        redis = mapOptionDefaults {
          USE_REDIS = cfg.redis.enable;
          REDIS_IP = cfg.redis.ip;
          REDIS_PORT = cfg.redis.port;
          REDIS_PW = toString cfg.redis.password;
        };
      in mkMerge [ defaults (mkIf cfg.redis.enable redis) ];
      nginxConfig = mkMerge [
        ''
          index index.php index.html index.htm;
          include ${config.services.nginx.package}/conf/fastcgi.conf;
          fastcgi_read_timeout 80s;
        ''
        (mkIf cfg.reverseProxy.enable ''
          fastcgi_pass_header "X-Accel-Buffering";
        '')
      ];
      nginxPhpConfig = mkAfter ''
        fastcgi_pass unix:${config.services.phpfpm.pools.barcodebuddy.socket};
      '';
      redis = let
        redis = config.services.redis.servers.${cfg.redis.server};
      in mkIf (cfg.redis.server != null) {
        enable = mkAlmostOptionDefault redis.enable;
        ip = mkOptionDefault (if redis.bind == null then "localhost" else redis.bind);
        port = mkIf (redis.port != 0) (mkOptionDefault redis.port);
        password = mkAlmostOptionDefault redis.requirePass;
        # TODO: passwordFile = mkAlmostOptionDefault redis.requirePassFile;
      };
    };
    conf.users.users.barcodebuddy = {
      isSystemUser = true;
      inherit (config.services.nginx) group;
    };

    conf.systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} - barcodebuddy nginx - -"
    ];

    conf.services.phpfpm.pools.barcodebuddy = {
      user = "barcodebuddy";
      inherit (config.services.nginx) group;

      phpPackage = cfg.phpPackageUnwrapped.withExtensions ({ enabled, all }: [
        all.curl
        all.mbstring
        all.sqlite3
        all.pdo
        all.pdo_sqlite
        all.sockets
        all.gettext
        all.session
        all.filter
        all.redis
      ]);

      settings = mapOptionDefaults {
        "pm.max_children" = 10;
        "pm" = "dynamic";
        "php_admin_value[error_log]" = "stderr";
        "php_admin_flag[log_errors]" = true;
        "listen.owner" = config.services.nginx.user;
        "catch_workers_output" = true;
        "pm.start_servers" = 1;
        "pm.min_spare_servers" = 1;
        "pm.max_spare_servers" = 2;
        "pm.max_requests" = 10;
      };

      phpEnv = mapAttrs' toPhpEnvPair cfg.settings;
    };

    # https://github.com/Forceu/barcodebuddy/blob/master/example/nginxConfiguration.conf
    conf.services.nginx = {
      enable = mkDefault true;
      virtualHosts."${cfg.hostName}" = {
        root = "${cfg.package}";
        locations = {
          "/api/".extraConfig = ''
            try_files $uri /api/index.php$is_args$query_string;
          '';
          "~ \\.php$".extraConfig = cfg.nginxPhpConfig;
        };
        extraConfig = cfg.nginxConfig;
      };
    };
    conf.systemd.services.bbuddy-websocket = mkIf cfg.screen.enable {
      wantedBy = [ "multi-user.target" ];
      environment = mapAttrs' toEnvPair cfg.settings;
      unitConfig = {
        Description = "Run websocket server for barcodebuddy screen feature";
      };
      serviceConfig = {
        ExecStart = "${config.services.phpfpm.pools.barcodebuddy.phpPackage}/bin/php ${cfg.package}/wsserver.php";
        Restart = "on-failure";
        StandardOutput = "null";
        User = "barcodebuddy";
      };
    };
  in mkMerge [ bbuddyConfig (mkIf cfg.enable conf) ];
}
