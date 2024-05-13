final: prev: let
  inherit (final) callPackage callPackages;
in {
  minecraft-bedrock-server = callPackage ../packages/minecraft-bedrock/server.nix {};
  minecraft-bedrock-server-libCrypto = callPackage ../packages/minecraft-bedrock/libcrypto.nix {};
  minecraft-bedrock-server-patchdebug = callPackage ../packages/minecraft-bedrock/patchdebug.nix {};
  minecraft-bedrock-server-patchelf = callPackage ../packages/minecraft-bedrock/patchelf.nix {};

  minecraft-bedrock-addons = callPackages ../packages/minecraft-bedrock/addons.nix {};
  mkMinecraftBedrockServerAddon = final.callPackage ../packages/minecraft-bedrock/mkaddon.nix {};
  unzipMcpack = final.callPackage ../packages/minecraft-bedrock/mcpack.nix {};
}
