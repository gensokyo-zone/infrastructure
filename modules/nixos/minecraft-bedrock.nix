let
  allowListModule = {
    config,
    name,
    gensokyo-zone,
    lib,
    ...
  }: let
    inherit (gensokyo-zone.Std) UInt;
    inherit (lib.options) mkOption;
    inherit (lib.modules) mkOptionDefault;
    inherit (builtins) typeOf;
  in {
    options = with lib.types; {
      name = mkOption {
        type = str;
        default = name;
      };
      xuid = mkOption {
        type = oneOf [int str];
      };
      permission = mkOption {
        type = enum ["visitor" "member" "operator"];
        default = "member";
      };
      settings = mkOption {
        type = attrsOf str;
      };
      permissionSettings = mkOption {
        type = attrsOf str;
      };
    };
    config = let
      xuid =
        {
          string = toString (UInt.FromHex config.xuid);
          int = toString config.xuid;
        }
        .${typeOf config.xuid};
    in {
      settings = {
        name = mkOptionDefault config.name;
        xuid = mkOptionDefault xuid;
        # TODO: ignoresPlayerLimit = true/false
      };
      permissionSettings = {
        xuid = mkOptionDefault xuid;
        permission = mkOptionDefault config.permission;
      };
    };
  };
  packModule = {
    config,
    lib,
    ...
  }: let
    inherit (lib.options) mkOption mkEnableOption;
    inherit (lib.modules) mkIf mkOptionDefault;
    inherit (lib.strings) splitString;
    inherit (builtins) typeOf;
  in {
    options = with lib.types; {
      enable =
        mkEnableOption "pack"
        // {
          default = true;
        };
      package = mkOption {
        type = nullOr package;
        default = null;
      };
      packDir = mkOption {
        type = str;
      };
      packType = mkOption {
        type = enum ["resource_packs" "behavior_packs"];
      };
      packId = mkOption {
        type = str;
      };
      version = mkOption {
        type = oneOf [str (listOf str)];
      };
      settings = mkOption {
        type = attrsOf (oneOf [str (listOf str)]);
      };
    };
    config = {
      packId = mkIf (config.package != null && config.package ? minecraft-bedrock.pack.pack_id) (
        mkOptionDefault
        config.package.minecraft-bedrock.pack.pack_id
      );
      packType = mkIf (config.package != null && config.package ? minecraft-bedrock.pack.type) (
        mkOptionDefault
        config.package.minecraft-bedrock.pack.type
      );
      version = mkIf (config.package != null && config.package ? minecraft-bedrock.pack.version) (
        mkOptionDefault
        config.package.minecraft-bedrock.pack.version
      );
      packDir = mkIf (config.package != null && config.package ? minecraft-bedrock.pack.dir) (
        mkOptionDefault
        config.package.minecraft-bedrock.pack.dir
      );
      settings = {
        pack_id = mkOptionDefault config.packId;
        version =
          mkOptionDefault
          {
            string = splitString "." config.version;
            list = config.version;
          }
          .${typeOf config.version};
      };
    };
  };
in
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
    inherit (lib.strings) concatStringsSep;
    inherit (lib.trivial) boolToString;
    inherit (lib.meta) getExe;
    inherit (builtins) toJSON;
    cfg = config.services.minecraft-bedrock-server;

    cfgToString = v:
      if builtins.isBool v
      then boolToString v
      else toString v;

    serverPropertiesFile = pkgs.writeText "server.properties" (''
        # server.properties managed by NixOS configuration
      ''
      + concatStringsSep "\n" (mapAttrsToList
        (n: v: "${n}=${cfgToString v}")
        cfg.serverProperties));
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
        type = nullOr (attrsOf (submoduleWith {
          modules = [allowListModule];
          specialArgs = {
            inherit gensokyo-zone;
            nixosConfig = config;
          };
        }));
        default = null;
      };

      allowList = mkOption {
        type = nullOr path;
      };

      permissions = mkOption {
        type = nullOr path;
      };

      packs = mkOption {
        type = attrsOf (submoduleWith {
          modules = [packModule];
          specialArgs = {
            inherit gensokyo-zone;
            nixosConfig = config;
          };
        });
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
        allowList = let
          allowPlayers = mapAttrsToList (_: allow: allow.settings) cfg.allowPlayers;
          allowListJson = pkgs.writeText "minecraft-bedrock-server-allowlist.json" (
            toJSON allowPlayers
          );
        in
          mkOptionDefault (
            if cfg.allowPlayers != null
            then allowListJson
            else null
          );
        permissions = let
          permissions = mapAttrsToList (_: allow: allow.permissionSettings) cfg.allowPlayers;
          permissionsJson = pkgs.writeText "minecraft-bedrock-server-permissions.json" (
            toJSON permissions
          );
        in
          mkOptionDefault (
            if cfg.allowPlayers != null
            then permissionsJson
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
              enabledPacks = filterAttrs (_: pack: pack.enable && pack.packType == "${type}_packs") cfg.packs;
              jsonName = "world_${type}_packs.json";
              packsJson = mapAttrsToList (_: pack: pack.settings) enabledPacks;
              packsJsonPath = pkgs.writeText jsonName (toJSON packsJson);
            in
              mkIf (enabledPacks != {}) [
                "${packsJsonPath}:${cfg.dataDir}/worlds/${cfg.serverProperties.level-name}/${jsonName}"
              ];
            mapWorldPacks = packs: let
              enabledPacks = filterAttrs (_: pack: pack.enable && pack.package != null) packs;
              mapPackPath = _: pack: let
                subDir = "${pack.packType}/${pack.packDir}";
              in "${pack.package}/${cfg.package.dataDir}/${subDir}:${cfg.dataDir}/${subDir}";
            in
              mapAttrsToList mapPackPath enabledPacks;
            packsPaths = mkMerge [
              (mkWorldPacks "behavior")
              (mkWorldPacks "resource")
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
          cp -f ${serverPropertiesFile} server.properties
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
