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
    "modules/nixos/ldap".functor.enable = true;
    "modules/nixos/krb5".functor.enable = true;
    "modules/nixos/sssd".functor.enable = true;
    "modules/nixos/network".functor.enable = true;
    "modules/nixos/nginx".functor.enable = true;
    "modules/nixos/steam".functor.enable = true;
    "modules/nixos/users".functor.enable = true;
    "modules/meta".functor.enable = true;
    "modules/system".functor.enable = true;
    "modules/system/network".functor.enable = true;
    "modules/system/proxmox".functor.enable = true;
    "modules/system/extern".functor.enable = true;
    "modules/system/exports".functor.enable = true;
    "modules/home".functor.enable = true;
    "modules/type".functor.enable = true;
    "modules/extern/home".functor.enable = true;
    "modules/extern/home/args".evaluate = true;
    "modules/extern/nixos".functor.enable = true;
    "modules/extern/nixos/args".evaluate = true;
    "modules/extern/misc/args".evaluate = true;
    "nixos/*".functor = {
      enable = true;
    };
    "overlays".evaluateDefault = true;
  };
})
