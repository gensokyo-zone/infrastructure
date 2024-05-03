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
    barcodebuddy.inputs = packages.x86_64-linux.barcodebuddy;
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
      legacyPackages.x86_64-linux.pkgs._389-ds-base
    ];
  };
}
