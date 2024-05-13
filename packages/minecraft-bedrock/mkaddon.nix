{
  stdenvNoCC,
  unzipMcpack,
  minecraft-bedrock-server,
  lib,
}: {
  src,
  pname,
  version,
  mcpackVersion ? version,
  mcVersion ? null,
  mcpackId,
  mcpackModules ? [],
  mcpackDir ? pname,
  mcpackType, # "behavior_packs" or "resource_packs" etc
  ...
} @ args: let
  inherit (lib.strings) optionalString splitString;
  inherit (minecraft-bedrock-server) dataDir;
  argNames = ["mcpackModules" "mcpackVersion" "mcpackId"];
in
  stdenvNoCC.mkDerivation (removeAttrs args argNames
    // {
      inherit dataDir mcpackType mcpackDir;
      version = version + optionalString (mcVersion != null) "-${mcVersion}";
      nativeBuildInputs =
        args.nativeBuildInputs
        or []
        ++ [
          unzipMcpack
        ];
      installPhase =
        args.installPhase
        or ''
          install -d "$out$dataDir/$mcpackType/$mcpackDir"
          cp -a ./* "$out$dataDir/$mcpackType/$mcpackDir/"

          install ./manifest.json $manifest
        '';
      outputs = ["out" "manifest"];
      passthru =
        args.passthru
        or {}
        // {
          minecraft-bedrock =
            args.passthru.minecraft-bedrock
            or {}
            // {
              pack =
                args.passthru.minecraft-bedrock.pack
                or {}
                // {
                  pack_id = mcpackId;
                  modules = mcpackModules;
                  version = splitString "." mcpackVersion;
                  type = mcpackType;
                  dir = mcpackDir;
                  subPath = "${dataDir}/${mcpackType}/${mcpackDir}";
                };
            };
        };
    })
