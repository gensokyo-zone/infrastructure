{inputs}: (inputs.tree.tree {
  inherit inputs;
  folder = ./.;
  config = {
    "/" = {
      excludes = [
        "tf"
        "default"
        "devShells"
        "outputs"
        "tree"
        "flake"
        "std"
        "inputs"
        "lib"
      ];
    };
    packages = {
      excludes = [
        "default"
      ];
    };
    systems = {
      excludes = [
        "default"
      ];
    };
    "systems/*" = {
      aliasDefault = true;
    };
    "modules/nixos" = {
      functor = {
        enable = true;
        external = with (import (inputs.arcexprs + "/modules")).nixos; [
          nix
          systemd
          dht22-exporter
          glauth
          modprobe
          kernel
          crypttab
          mutable-state
          common-root
          pulseaudio
          wireplumber
          alsa
          bindings
          matrix-appservices
          matrix-synapse-appservices
          display
          filebin
          mosh
          doc-warnings
          inputs.systemd2mqtt.nixosModules.default
        ];
      };
    };
    "modules/nixos/network".functor.enable = true;
    "modules/nixos/nginx".functor.enable = true;
    "modules/nixos/steam".functor.enable = true;
    "modules/meta".functor.enable = true;
    "modules/system".functor.enable = true;
    "modules/system/proxmox".functor.enable = true;
    "modules/system/extern".functor.enable = true;
    "modules/home".functor.enable = true;
    "modules/type".functor.enable = true;
    "nixos/*".functor = {
      enable = true;
    };
    "hardware".evaluateDefault = true;
    "nixos/cross".evaluateDefault = true;
    "hardware/*".evaluateDefault = true;
    "home".evaluateDefault = true;
    "home/*".functor.enable = true;
  };
})
