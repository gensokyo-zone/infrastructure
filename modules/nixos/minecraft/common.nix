let
  allowListModule = {
    config,
    name,
    gensokyo-zone,
    lib,
    ...
  }: let
    inherit (gensokyo-zone.Std) UInt;
    inherit (gensokyo-zone.lib) json;
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
        type = nullOr (oneOf [int str]);
      };
      uuid = mkOption {
        type = nullOr str;
      };
      permission = mkOption {
        type = enum ["visitor" "member" "operator"];
        default = "member";
      };
      permissionLevel = mkOption {
        type = ints.between 0 4;
        description = "1=mod, 2=gm, 3=admin, 4=owner";
        default = 0;
      };
      settings = mkOption {
        type = json.types.attrs;
      };
      whitelistSettings = mkOption {
        type = json.types.attrs;
      };
      permissionSettings = mkOption {
        type = json.types.attrs;
      };
      opsSettings = mkOption {
        type = json.types.attrs;
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
      whitelistSettings = {
        name = mkOptionDefault config.name;
        uuid = mkOptionDefault config.uuid;
      };
      permissionSettings = {
        xuid = mkOptionDefault xuid;
        permission = mkOptionDefault config.permission;
      };
      opsSettings = {
        name = mkOptionDefault config.name;
        uuid = mkOptionDefault config.uuid;
        level = mkOptionDefault config.permissionLevel;
        bypassesPlayerLimit = mkOptionDefault true;
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
    inherit (lib.attrsets) mapAttrsToList filterAttrs;
    inherit (lib.strings) concatStringsSep;
    inherit (lib.trivial) boolToString;
    inherit (builtins) toJSON;
    inherit (config.lib) minecraft;
  in {
    config.lib.minecraft = {
      inherit allowListModule packModule;
      mkAllowPlayerType = {
        modules ? [],
        specialArgs ? {},
      }:
        lib.types.submoduleWith {
          modules = modules ++ [minecraft.allowListModule];
          specialArgs =
            {
              inherit gensokyo-zone;
              nixosConfig = config;
            }
            // specialArgs;
        };
      writeAllowList = allowPlayers: let
        allowList = mapAttrsToList (_: allow: allow.settings) allowPlayers;
      in
        pkgs.writeText "allowlist.json" (toJSON allowList);
      writeWhiteList = allowPlayers: let
        allowList = mapAttrsToList (_: allow: allow.whitelistSettings) allowPlayers;
      in
        pkgs.writeText "whitelist.json" (toJSON allowList);
      writePermissions = allowPlayers: let
        permissions = mapAttrsToList (_: allow: allow.permissionSettings) allowPlayers;
      in
        pkgs.writeText "permissions.json" (toJSON permissions);
      writeOps = allowPlayers: let
        ops = filterAttrs (_: player: player.permissionLevel > 0) allowPlayers;
        permissions = mapAttrsToList (_: allow: allow.opsSettings) ops;
      in
        pkgs.writeText "ops.json" (toJSON permissions);
      mkPackType = {
        modules ? [],
        specialArgs ? {},
      }:
        lib.types.submoduleWith {
          modules = modules ++ [minecraft.packModule];
          specialArgs =
            {
              inherit gensokyo-zone;
              nixosConfig = config;
            }
            // specialArgs;
        };
      writePacks = {type}: packs: let
        packsSettings = mapAttrsToList (_: pack: pack.settings) packs;
      in
        pkgs.writeText "world_${type}.json" (toJSON packsSettings);
      writeServerProperty = let
        cfgToString = v:
          if builtins.isBool v
          then boolToString v
          else toString v;
      in
        n: v: "${n}=${cfgToString v}";
      writeServerProperties = serverProperties: let
        inherit (config.lib.minecraft) writeServerProperty;
        lines = mapAttrsToList writeServerProperty serverProperties;
      in
        pkgs.writeText "server.properties" ''
          # server.properties managed by NixOS configuration
          ${concatStringsSep "\n" lines}
        '';
    };
  }
