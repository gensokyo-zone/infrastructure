{
  ci = {
    workflowConfigs = [
      "nodes.nix"
      "flake-cron.nix"
    ];
    nixosSystems = [
      "hakurei"
      "reimu"
      "aya"
      "tei"
      "litterbox"
      "keycloak"
      "mediabox"
    ];
  };
}
