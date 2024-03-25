{
  ci = {
    workflowConfigs = [
      "nodes.nix"
      "flake-cron.nix"
    ];
    nixosSystems = [
      "ct"
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
