{
  inputs,
  ...
}: let
  inherit (inputs.self.lib) nixlib;
in rec {
  default = nixlib.composeManyExtensions [
    barcodebuddy
    minecraft
    krb5
    nfs
    nginx
    samba
  ];
  barcodebuddy = import ./barcodebuddy.nix;
  krb5 = import ./krb5.nix;
  minecraft = import ./minecraft.nix;
  nfs = import ./nfs.nix;
  nginx = import ./nginx.nix;
  samba = import ./samba.nix;
  deploy-rs = inputs.deploy-rs.overlays.default or inputs.deploy-rs.overlay;
  arc = inputs.arcexprs.overlays.default;
}
