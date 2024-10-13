let
  javaServerModule = {
    config,
    nixosConfig,
    gensokyo-zone,
    lib,
    pkgs,
    ...
  }: let
    inherit (gensokyo-zone.lib) mapOptionDefaults unmerged;
    inherit (lib.options) mkOption mkEnableOption mkPackageOption;
    inherit (lib.modules) mkIf mkAfter mkOptionDefault;
    inherit (lib.strings) escapeShellArgs;
    inherit (lib.meta) getExe;
    inherit (nixosConfig.lib.minecraft) mkAllowPlayerType writeWhiteList writeOps;
    defaultPort = 25565;
  in {
    options = with lib.types; {
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
        default = config.user;
      };

      serverProperties = mkOption {
        type = attrsOf (oneOf [bool int str float]);
      };

      allowPlayers = mkOption {
        type = nullOr (attrsOf (mkAllowPlayerType {}));
        default = null;
      };

      conf = {
        systemdService = mkOption {
          type = unmerged.types.attrs;
        };
        systemdSocket = mkOption {
          type = unmerged.types.attrs;
        };
        users = mkOption {
          type = unmerged.types.attrs;
          default = {};
        };
        networkingFirewall = mkOption {
          type = unmerged.types.attrs;
          default = {};
        };
      };
    };

    config = {
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
        "query.port" = config.serverProperties.server-port or defaultPort;
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

      conf.users = mkIf (config.user == "minecraft-bedrock") {
        users.${config.user} = {
          inherit (config) group;
          description = "Minecraft server service user";
          home = config.dataDir;
          createHome = true;
          isSystemUser = true;
        };
        groups.${config.group} = {};
      };

      conf.systemdService = let
        execStartArgs =
          map (argsFile: "@${argsFile}") config.argsFiles
          ++ config.jvmOpts;
        execStop = pkgs.writeShellScriptBin "minecraft-java-stop" ''
          echo /stop > ${nixosConfig.systemd.sockets.minecraft-java-server.socketConfig.ListenFIFO} || true

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
          config.dataDir
          config.jvmOpts
          config.argsFiles
        ];

        path = [config.jre.package];
        script = mkAfter ''
          exec java ${escapeShellArgs execStartArgs}
        '';

        serviceConfig = {
          BindReadOnlyPaths = mkIf (config.allowPlayers != null) [
            "${writeWhiteList config.allowPlayers}:${config.dataDir}/whitelist.json"
            "${writeOps config.allowPlayers}:${config.dataDir}/ops.json"
          ];
          ExecStop = getExe execStop;
          Restart = "always";
          RestartSec = 3;
          User = config.user;
          WorkingDirectory = config.dataDir;
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
      conf.systemdSocket = {
        partOf = ["minecraft-java-server.service"];
        socketConfig = {
          ListenFIFO = "/run/minecraft-java/stdin";
          SocketMode = "0660";
          SocketUser = mkOptionDefault config.user;
          SocketGroup = mkOptionDefault config.group;
          RemoveOnStop = true;
          FlushPending = true;
        };
      };

      conf.networkingFirewall = mkIf config.openFirewall {
        allowedUDPPorts = config.port;
      };
    };
  };
in {
  pkgs,
  config,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (gensokyo-zone.lib) unmerged;
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkMerge;
  cfg = config.services.minecraft-java-server;
in {
  # TODO: attrsOf submodule
  options.services.minecraft-java-server = with lib.types; mkOption {
    type = submoduleWith {
      modules = [javaServerModule];
      specialArgs = {
        inherit gensokyo-zone pkgs;
        nixosConfig = config;
      };
    };
    default = {};
  };

  config = let
    serviceConf.users = unmerged.mergeAttrs cfg.conf.users;
    serviceConf.systemd.services.minecraft-java-server = unmerged.mergeAttrs cfg.conf.systemdService;
    serviceConf.systemd.sockets.minecraft-java-server = unmerged.mergeAttrs cfg.conf.systemdSocket;
    serviceConf.networking.firewall = unmerged.mergeAttrs cfg.conf.networkingFirewall;
    conf.lib.minecraft = {
      inherit javaServerModule;
    };
  in mkMerge [
    (mkIf cfg.enable serviceConf)
    conf
  ];
}
