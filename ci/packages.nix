{
  lib,
  config,
  channels,
  ...
}: let
  inherit (channels.nixfiles) packages legacyPackages;
in {
  tasks = {
    devShell.inputs = with packages.x86_64-linux; [
      deploy-rs
      terraform tflint
      alejandra deadnix statix
      ssh-to-age
    ];

    # build+cache packages customized or added via overlay
    barcodebuddy.inputs = with packages.x86_64-linux; [
      barcodebuddy
      barcodebuddy-scanner
      barcodebuddy-scanner-python
    ];
    samba.inputs = with packages.x86_64-linux; [
      legacyPackages.x86_64-linux.pkgs.samba
      samba-ldap
      freeipa-ipasam
    ];
    nfs.inputs = [
      packages.x86_64-linux.nfs-utils-ldap
    ];
    krb5.inputs = [
      packages.x86_64-linux.krb5-ldap
      legacyPackages.x86_64-linux.pkgs.sssd
      legacyPackages.x86_64-linux.pkgs.freeipa
    ];
    openwebrx.inputs = [
      packages.x86_64-linux.openwebrxplus
      # TODO: packages.aarch64-linux.openwebrxplus
    ];
    print.inputs = [
      #legacyPackages.x86_64-linux.pkgs.cura-octoprint
      legacyPackages.x86_64-linux.pkgs.niimprint
    ];
    systemd2mqtt.inputs = [
      packages.x86_64-linux.systemd2mqtt
    ];
  };
}
