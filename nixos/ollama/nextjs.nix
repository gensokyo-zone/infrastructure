{
  pkgs,
  config,
  gensokyo-zone,
  access,
  lib,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.modules) mkDefault;
in {
  services.nextjs-ollama-llm-ui = {
    enable = mkDefault true;
    ollamaUrl = mkAlmostOptionDefault (access.proxyUrlFor {serviceName = "ollama";});
    port = mkAlmostOptionDefault 3001;
  };
}
