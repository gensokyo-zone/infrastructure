  {
    config,
    gensokyo-zone,
    lib,
    pkgs,
    ...
  }: let
    # see https://gist.github.com/datakurre/cfdf627fb23ed8ff62bb7b3520b92674
    inherit (gensokyo-zone.lib) mapOptionDefaults;
    inherit (lib.options) mkOption mkPackageOption;
    inherit (lib.modules) mkIf mkMerge mkOptionDefault;
    inherit (lib.attrsets) filterAttrs mapAttrsToList;
    inherit (lib.lists) optional;
    inherit (lib.meta) getExe;
    inherit (config.lib.minecraft) mkAllowPlayerType mkPackType writeServerProperties writeAllowList writePermissions writePacks;
    cfg = config.services.minecraft-bedrock-server;
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
        type = attrsOf (oneOf [bool int str float]);
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

      package =
        mkPackageOption pkgs "minecraft-bedrock-server" {}
        // {
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

      allowPlayers = mkOption {
        type = nullOr (attrsOf (mkAllowPlayerType {}));
        default = null;
      };

      allowList = mkOption {
        type = nullOr path;
      };

      permissions = mkOption {
        type = nullOr path;
      };

      packs = mkOption {
        type = attrsOf (mkPackType {});
        default = {};
      };
    };

    config = let
      confService.services.minecraft-bedrock-server = {
        serverProperties = mapOptionDefaults {
          server-name = "Dedicated Server";
          gamemode = "survival";
          difficulty = "easy";
          allow-cheats = false;
          max-players = 10;
          online-mode = false;
          allow-list = cfg.allowList != null;
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
        allowList = mkOptionDefault (
          if cfg.allowPlayers != null
          then writeAllowList cfg.allowPlayers
          else null
        );
        permissions = mkOptionDefault (
          if cfg.allowPlayers != null
          then writePermissions cfg.allowPlayers
          else null
        );
      };
      conf.users.users.${cfg.user} = {
        inherit (cfg) group;
        description = "Minecraft server service user";
        home = cfg.dataDir;
        createHome = true;
        isSystemUser = true;
      };
      conf.users.groups.${cfg.group} = {};

      conf.systemd.services.minecraft-bedrock-server = {
        description = "Minecraft Bedrock Server Service";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];

        serviceConfig = {
          BindReadOnlyPaths = let
            packageResources = map (subpath: "${cfg.package}/var/lib/minecraft-bedrock/${subpath}:${cfg.dataDir}/${subpath}") ([
                "definitions/attachables"
                "definitions/biomes"
                "definitions/feature_rules"
                "definitions/features"
                "definitions/persona"
                "definitions/sdl_layouts"
                "definitions/spawn_groups"
                "resource_packs/vanilla"
                "resource_packs/chemistry"
                "config/default"
                "bedrock_server_symbols.debug"
                "env-vars"
              ]
              ++ optional (cfg.permissions == null) "permissions.json");
            mkWorldPacks = type: let
              enabledPacks = filterAttrs (_: pack: pack.enable && pack.packType == type) cfg.packs;
              packsJsonPath = writePacks { inherit type; } enabledPacks;
            in
              mkIf (enabledPacks != {}) [
                "${packsJsonPath}:${cfg.dataDir}/worlds/${cfg.serverProperties.level-name}/${packsJsonPath.name}"
              ];
            mapWorldPacks = packs: let
              enabledPacks = filterAttrs (_: pack: pack.enable && pack.package != null) packs;
              mapPackPath = _: pack: let
                subDir = "${pack.packType}/${pack.packDir}";
              in "${pack.package}/${cfg.package.dataDir}/${subDir}:${cfg.dataDir}/${subDir}";
            in
              mapAttrsToList mapPackPath enabledPacks;
            packsPaths = mkMerge [
              (mkWorldPacks "behavior_packs")
              (mkWorldPacks "resource_packs")
              (mapWorldPacks cfg.packs)
            ];
          in
            mkMerge [
              packageResources
              (mkIf (cfg.allowList != null) ["${cfg.allowList}:${cfg.dataDir}/allowlist.json"])
              (mkIf (cfg.permissions != null) ["${cfg.permissions}:${cfg.dataDir}/permissions.json"])
              (mkIf (cfg.packs != {}) packsPaths)
            ];
          ExecStart = [
            "${getExe cfg.package}"
          ];
          Restart = "always";
          User = cfg.user;
          WorkingDirectory = cfg.dataDir;
          LogFilterPatterns = [
            "~.*minecraft:trial_chambers/chamber/end"
            "~Running AutoCompaction"
          ];
        };

        preStart = ''
          mkdir -p behavior_packs
          ln -sf ${cfg.package}/var/lib/minecraft-bedrock/behavior_packs/* behavior_packs/
          cp -f ${writeServerProperties cfg.serverProperties} server.properties
          chmod +w server.properties
        '';
      };

      conf.networking.firewall = let
        ports = [cfg.serverProperties.server-port cfg.serverProperties.server-portv6];
      in
        mkIf cfg.openFirewall {
          allowedUDPPorts = ports;
        };
    in
      mkMerge [
        confService
        (mkIf cfg.enable conf)
      ];
  }
