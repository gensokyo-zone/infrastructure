{
  inputs,
  ...
}: let
  inherit (inputs.self.lib) nixlib;
in rec {
  default = nixlib.composeManyExtensions [
    barcodebuddy
    krb5
    minecraft
    nfs
    nginx
    openwebrx
    samba
  ];
  barcodebuddy = import ./barcodebuddy.nix;
  krb5 = import ./krb5.nix;
  minecraft = import ./minecraft.nix;
  nfs = import ./nfs.nix;
  nginx = import ./nginx.nix;
  samba = import ./samba.nix;
  openwebrx = import ./openwebrxplus.nix;
  deploy-rs = inputs.deploy-rs.overlays.default or inputs.deploy-rs.overlay;
  arc = inputs.arcexprs.overlays.default;
}
