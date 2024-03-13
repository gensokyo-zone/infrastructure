{
  inputs,
  system,
}: {
  pkgs = import inputs.nixpkgs {
    inherit system;
    overlays = [
      inputs.deploy-rs.overlay
      inputs.arcexprs.overlays.default
      (final: prev: {
        jemalloc =
          if final.hostPlatform != "aarch64-darwin"
          then prev.jemalloc
          else null;
      })
    ];
    config = {
      allowUnfree = true;
      allowBroken = true;
      allowUnsupportedSystem = false;
      permittedInsecurePackages = [
        "ffmpeg-3.4.8"
        "ffmpeg-2.8.17"
        "openssl-1.1.1w"
      ];
    };
  };
}
