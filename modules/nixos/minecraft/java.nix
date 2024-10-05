{
  config,
  gensokyo-zone,
  lib,
  pkgs,
  ...
}: let
  inherit (gensokyo-zone.lib) mapOptionDefaults;
  inherit (lib.options) mkOption mkEnableOption mkPackageOption;
  inherit (lib.modules) mkIf mkMerge mkAfter mkOptionDefault;
  inherit (lib.strings) escapeShellArgs;
  inherit (lib.meta) getExe;
  inherit (config.lib.minecraft) mkAllowPlayerType writeWhiteList writeOps;
  cfg = config.services.minecraft-java-server;
  defaultPort = 25565;
in {
  options.services.minecraft-java-server = with lib.types; {
    enable = mkEnableOption "minecraft java edition server";

    openFirewall = mkOption {
      type = bool;
      default = false;
    };
    port = mkOption {
      type = port;
      default = defaultPort;
    };

    jre.package = mkPackageOption pkgs "jre" {};

    dataDir = mkOption {
      type = path;
      default = "/var/lib/minecraft-java";
      description = ''
        Directory to store Minecraft database and other state/data files.
      '';
    };

    argsFiles = mkOption {
      type = listOf str;
      default = ["user_jvm_args.txt"];
    };

    jvmOpts = mkOption {
      type = listOf str;
      default = [];
      example = ["-Xmx4G"];
    };

    user = mkOption {
      type = str;
      default = "minecraft-bedrock";
    };
    group = mkOption {
      type = str;
      default = cfg.user;
    };

    serverProperties = mkOption {
      type = attrsOf (oneOf [bool int str float]);
    };

    allowPlayers = mkOption {
      type = nullOr (attrsOf (mkAllowPlayerType {}));
      default = null;
    };
  };

  config = let
    confService.services.minecraft-java-server = {
      # TODO: fill with defaults
      serverProperties = mapOptionDefaults {
        enable-jmx-monitoring = false;
        "rcon.port" = 25575;
        level-seed = "";
        gamemode = "survival";
        enable-command-block = false;
        enable-query = false;
        generator-settings = {};
        enforce-secure-profile = true;
        level-name = "world";
        motd = "A Minecraft Server";
        #"query.port" = defaultPort;
        "query.port" = cfg.serverProperties.server-port or defaultPort;
        pvp = true;
        generate-structures = true;
        max-chained-neighbor-updates = 1000000;
        difficulty = "easy";
        network-compression-threshold = 256;
        max-tick-time = 60000;
        require-resource-pack = false;
        use-native-transport = true;
        max-players = 20;
        online-mode = true;
        enable-status = true;
        allow-flight = false;
        initial-disabled-packs = "";
        broadcast-rcon-to-ops = true;
        view-distance = 10;
        server-ip = "";
        resource-pack-prompt = "";
        allow-nether = true;
        server-port = defaultPort;
        enable-rcon = false;
        sync-chunk-writes = true;
        op-permission-level = 4;
        prevent-proxy-connections = false;
        hide-online-players = false;
        resource-pack = "";
        entity-broadcast-range-percentage = 100;
        simulation-distance = 10;
        "rcon.password" = "";
        player-idle-timeout = 0;
        force-gamemode = false;
        rate-limit = 0;
        hardcore = false;
        white-list = false;
        broadcast-console-to-ops = true;
        spawn-npcs = true;
        spawn-animals = true;
        log-ips = true;
        function-permission-level = 2;
        initial-enabled-packs = "vanilla";
        level-type = "minecraft\\:normal";
        text-filtering-config = "";
        spawn-monsters = true;
        enforce-whitelist = false;
        spawn-protection = 16;
        resource-pack-sha1 = "";
        max-world-size = 29999984;
      };
    };
    conf.users = mkIf (cfg.user == "minecraft-bedrock") {
      users.${cfg.user} = {
        inherit (cfg) group;
        description = "Minecraft server service user";
        home = cfg.dataDir;
        createHome = true;
        isSystemUser = true;
      };
      groups.${cfg.group} = {};
    };

    conf.systemd.services.minecraft-java-server = let
      execStartArgs =
        map (argsFile: "@${argsFile}") cfg.argsFiles
        ++ cfg.jvmOpts;
      execStop = pkgs.writeShellScriptBin "minecraft-java-stop" ''
        echo /stop > ${config.systemd.sockets.minecraft-java-server.socketConfig.ListenFIFO} || true

        if [[ -n ''${MAINPID-} ]]; then
          # Wait for the PID of the minecraft server to disappear before
          # returning, so systemd doesn't attempt to SIGKILL it.
          while kill -0 "$MAINPID" 2> /dev/null; do
            sleep 1s
          done
        fi
      '';
    in {
      description = "Minecraft Kat Kitchen Server";
      wantedBy = ["multi-user.target"];
      requires = ["minecraft-java-server.socket"];
      after = ["network.target" "minecraft-java-server.socket"];

      restartIfChanged = false;
      restartTriggers = [
        cfg.dataDir
        cfg.jvmOpts
        cfg.argsFiles
      ];

      path = [cfg.jre.package];
      script = mkAfter ''
        exec java ${escapeShellArgs execStartArgs}
      '';

      serviceConfig = {
        BindReadOnlyPaths = mkIf (cfg.allowPlayers != null) [
          "${writeWhiteList cfg.allowPlayers}:${cfg.dataDir}/whitelist.json"
          "${writeOps cfg.allowPlayers}:${cfg.dataDir}/ops.json"
        ];
        ExecStop = getExe execStop;
        Restart = "always";
        RestartSec = 3;
        User = cfg.user;
        WorkingDirectory = cfg.dataDir;
        RuntimeDirectory = "minecraft-java";

        StandardInput = "socket";
        StandardOutput = "journal";
        StandardError = "journal";

        # Hardening
        CapabilityBoundingSet = [""];
        DeviceAllow = [""];
        LockPersonality = true;
        PrivateDevices = true;
        PrivateTmp = true;
        PrivateUsers = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        UMask = "0077";
      };
    };
    conf.systemd.sockets.minecraft-java-server = {
      partOf = ["minecraft-java-server.service"];
      socketConfig = {
        ListenFIFO = "/run/minecraft-java/stdin";
        SocketMode = "0660";
        SocketUser = mkOptionDefault cfg.user;
        SocketGroup = mkOptionDefault cfg.group;
        RemoveOnStop = true;
        FlushPending = true;
      };
    };

    conf.networking.firewall = mkIf cfg.openFirewall {
      allowedUDPPorts = cfg.port;
    };
  in
    mkMerge [
      confService
      (mkIf cfg.enable conf)
    ];
}
