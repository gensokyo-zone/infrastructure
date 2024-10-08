{inputs, ...}: let
  inherit (inputs.self.lib) nixlib;
in rec {
  default = nixlib.composeManyExtensions [
    barcodebuddy
    builders
    krb5
    llm
    minecraft
    nfs
    nginx
    openwebrx
    print
    samba
  ];
  barcodebuddy = import ./barcodebuddy.nix;
  krb5 = import ./krb5.nix;
  llm = import ./llm.nix;
  minecraft = import ./minecraft.nix;
  nfs = import ./nfs.nix;
  nginx = import ./nginx.nix;
  samba = import ./samba.nix;
  openwebrx = import ./openwebrxplus.nix;
  print = import ./print.nix;
  builders = import ./builders.nix;
  deploy-rs = inputs.deploy-rs.overlays.default or inputs.deploy-rs.overlay;
  systemd2mqtt = inputs.systemd2mqtt.overlays.default;
  arc = inputs.arcexprs.overlays.default;
}
