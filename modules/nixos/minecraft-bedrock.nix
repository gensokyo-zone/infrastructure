{ config, lib, pkgs, ... }: let
  # see https://gist.github.com/datakurre/cfdf627fb23ed8ff62bb7b3520b92674
  inherit (lib.options) mkOption mkPackageOption;
  inherit (lib.modules) mkIf;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.strings) concatStringsSep;
  inherit (lib.trivial) boolToString;
  cfg = config.services.minecraft-bedrock-server;

  cfgToString = v: if builtins.isBool v then boolToString v else toString v;

  serverPropertiesFile = pkgs.writeText "server.properties" (''
    # server.properties managed by NixOS configuration
  '' + concatStringsSep "\n" (mapAttrsToList
    (n: v: "${n}=${cfgToString v}") cfg.serverProperties));
in {
  options.services.minecraft-bedrock-server = with lib.types; {
    enable = mkOption {
      type = bool;
      default = false;
      description = ''
        If enabled, start a Minecraft Bedrock Server. The server
        data will be loaded from and saved to
        <option>services.minecraft-bedrock-server.dataDir</option>.
      '';
    };

    dataDir = mkOption {
      type = path;
      default = "/var/lib/minecraft-bedrock";
      description = ''
        Directory to store Minecraft Bedrock database and other state/data files.
      '';
    };

    serverProperties = mkOption {
      type = attrsOf (oneOf [ bool int str float ]);
      default = {
        server-name = "Dedicated Server";
        gamemode = "survival";
        difficulty = "easy";
        allow-cheats = false;
        max-players = 10;
        online-mode = false;
        white-list = false;
        server-port = 19132;
        server-portv6 = 19133;
        view-distance = 32;
        tick-distance = 4;
        player-idle-timeout = 30;
        max-threads = 8;
        level-name = "Bedrock level";
        level-seed = "";
        default-player-permission-level = "member";
        texturepack-required = false;
        content-log-file-enabled = false;
        compression-threshold = 1;
        server-authoritative-movement = "server-auth";
        player-movement-score-threshold = 20;
        player-movement-distance-threshold = 0.3;
        player-movement-duration-threshold-in-ms = 500;
        correct-player-movement = false;
      };
      example = literalExample ''
        {
          server-name = "Dedicated Server";
          gamemode = "survival";
          difficulty = "easy";
          allow-cheats = false;
          max-players = 10;
          online-mode = false;
          white-list = false;
          server-port = 19132;
          server-portv6 = 19133;
          view-distance = 32;
          tick-distance = 4;
          player-idle-timeout = 30;
          max-threads = 8;
          level-name = "Bedrock level";
          level-seed = "";
          default-player-permission-level = "member";
          texturepack-required = false;
          content-log-file-enabled = false;
          compression-threshold = 1;
          server-authoritative-movement = "server-auth";
          player-movement-score-threshold = 20;
          player-movement-distance-threshold = 0.3;
          player-movement-duration-threshold-in-ms = 500;
          correct-player-movement = false;
        }
      '';
      description = ''
        Minecraft Bedrock server properties for the server.properties file.
      '';
    };

    package = mkPackageOption pkgs "minecraft-bedrock-server" { }// {
      description = "Version of minecraft-bedrock-server to run.";
    };

    openFirewall = mkOption {
      type = bool;
      default = false;
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

  config = mkIf cfg.enable {
    users.users.${cfg.user} = {
      inherit (cfg) group;
      description     = "Minecraft server service user";
      home            = cfg.dataDir;
      createHome      = true;
      isSystemUser = true;
    };
    users.groups.${cfg.group} = {};

    systemd.services.minecraft-bedrock-server = {
      description   = "Minecraft Bedrock Server Service";
      wantedBy      = [ "multi-user.target" ];
      after         = [ "network.target" ];

      serviceConfig = {
        ExecStart = [
          "${cfg.package}/bin/bedrock_server"
        ];
        Restart = "always";
        User = cfg.user;
        WorkingDirectory = cfg.dataDir;
      };

      preStart = ''
        cp -a -n ${cfg.package}/var/lib/* .
        cp -f ${serverPropertiesFile} server.properties
        chmod +w server.properties
      '';
    };

    networking.firewall = let
      ports = [ cfg.serverProperties.server-port cfg.serverProperties.server-portv6 ];
    in mkIf cfg.openFirewall {
      allowedUDPPorts = ports;
    };
  };
}
