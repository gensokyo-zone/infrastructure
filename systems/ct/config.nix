_: {
  arch = "x86_64";
  type = "NixOS";
  modules = [
    ({
      meta,
      lib,
      ...
    }: {
      imports = with meta; [
        nixos.reisen-ct
      ];

      system.stateVersion = "23.11";
    })
  ];
}
