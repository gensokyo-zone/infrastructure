{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption mkPackageOption;
  inherit (lib.modules) mkIf mkMerge mkOptionDefault;
  inherit (lib.strings) concatStringsSep;
  inherit (lib.meta) getExe;
  cfg = config.services.minecraft-katsink-server;

in {
  options.services.minecraft-katsink-server = with lib.types; {
    enable = mkEnableOption "kat-kitchen-sink";

    openFirewall = mkOption {
      type = bool;
      default = false;
    };
    port = mkOption {
      type = port;
      default = 25565;
    };

    jre.package = mkPackageOption pkgs "jre" {};

    dataDir = mkOption {
      type = path;
      default = "/var/lib/minecraft-katsink";
      description = ''
        Directory to store Minecraft database and other state/data files.
      '';
    };

    argsFiles = mkOption {
      type = listOf str;
      default = [ "user_jvm_args.txt" ];
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
  };

  config = let
    confService.services.minecraft-katsink-server = {
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

    conf.systemd.services.minecraft-katsink-server = let
      execStart = concatStringsSep " " ([
        "${getExe cfg.jre.package}"
      ] ++ map (argsFile: "@${argsFile}") cfg.argsFiles
      ++ cfg.jvmOpts);
      execStop = pkgs.writeShellScriptBin "minecraft-katsink-stop" ''
        echo /stop > ${config.systemd.sockets.minecraft-katsink-server.socketConfig.ListenFIFO}

        # Wait for the PID of the minecraft server to disappear before
        # returning, so systemd doesn't attempt to SIGKILL it.
        while kill -0 "$1" 2> /dev/null; do
          sleep 1s
        done
      '';

    in {
      description = "Minecraft Kat Kitchen Server";
      wantedBy = ["multi-user.target"];
      requires = ["minecraft-katsink-server.socket"];
      after = ["network.target" "minecraft-katsink-server.socket"];

      restartTriggers = [
        cfg.dataDir
        cfg.jvmOpts
        cfg.argsFiles
      ];

      serviceConfig = {
        ExecStart = [execStart];
        ExecStop = "${getExe execStop} $MAINPID";
        Restart = "on-failure";
        User = cfg.user;
        WorkingDirectory = cfg.dataDir;
        /*LogFilterPatterns = [
          "~.*minecraft:trial_chambers/chamber/end"
          "~Running AutoCompaction"
        ];*/

        StandardInput = "socket";
        StandardOutput = "journal";
        StandardError = "journal";

        # Hardening
        CapabilityBoundingSet = [ "" ];
        DeviceAllow = [ "" ];
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
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        UMask = "0077";
      };
    };
    conf.systemd.sockets.minecraft-katsink-server = {
      bindsTo = [ "minecraft-katsink-server.service" ];
      socketConfig = {
        ListenFIFO = "/run/minecraft-katsink.stdin";
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
