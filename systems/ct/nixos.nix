{
  meta,
  lib,
  ...
}: {
  imports = with meta;
    [
      nixos.reisen-ct
    ];

  system.stateVersion = "23.11";
}
