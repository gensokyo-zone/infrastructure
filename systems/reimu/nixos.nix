{meta, ...}: {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.sops
    nixos.base
    nixos.reisen-ct
    nixos.kyuuto
    nixos.steam.account-switch
    nixos.steam.beatsaber
    nixos.tailscale
    nixos.ipa
    nixos.ldap
    nixos.nfs
  ];

  kyuuto.setup = true;
  services.steam = {
    accountSwitch.enable = false;
    beatsaber.enable = false;
  };

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "23.11";
}
