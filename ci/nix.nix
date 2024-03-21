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
      "utsuho"
      "tei"
      "litterbox"
      "keycloak"
      "mediabox"
    ];
  };
}
