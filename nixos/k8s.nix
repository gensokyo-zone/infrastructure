{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkForce;
  inherit (lib.strings) escapeShellArgs;
  kubeMasterIP = "10.1.1.173";
  kubeMasterHostname = "k8s.gensokyo.zone";
  kubeMasterAPIServerPort = 6443;
in {
  # packages for administration tasks
  environment.systemPackages = with pkgs; [
    kompose
    kubectl
    kubernetes
  ];

  networking = {
    firewall.enable = mkForce false;
    nftables.enable = mkForce false;
    extraHosts = "${kubeMasterIP} ${kubeMasterHostname}";
  };

  systemd.services.etcd.preStart = ''${pkgs.writeShellScript "etcd-wait" ''
      while [ ! -f /var/lib/kubernetes/secrets/etcd.pem ]; do sleep 1; done
    ''}'';

  services.kubernetes = {
    roles = ["master" "node"];
    addons.dns.enable = false;
    flannel.enable = false;
    easyCerts = true;
    masterAddress = kubeMasterHostname;
    clusterCidr = "10.42.0.0/16";
    apiserverAddress = "https://${kubeMasterHostname}:${toString kubeMasterAPIServerPort}";
    apiserver = {
      serviceClusterIpRange = "10.43.0.0/16";
      securePort = kubeMasterAPIServerPort;
      advertiseAddress = kubeMasterIP;
      extraOpts = escapeShellArgs [
        "--service-node-port-range=1-65535"
      ];
      allowPrivileged = true;
    };
    kubelet = {
      extraOpts = "--fail-swap-on=false";
      clusterDns = "10.43.0.2";
    };
  };

  # --- Credit for section to @duckfullstop --- #

  # Set CRI binary directory to location where they'll be dropped by kubernetes setup containers
  # important note: this only works if the container drops a statically linked binary,
  # as dynamically linked ones would be looking for binaries that only exist in the nix store
  # (and not in conventional locations)
  virtualisation.containerd.settings = {
    plugins."io.containerd.grpc.v1.cri" = {
      containerd.snapshotter = "overlayfs";
      cni.bin_dir = "/opt/cni/bin";
    };
  };

  # disable creating the CNI directory (cluster CNI make it for us)
  environment.etc."cni/net.d".enable = false;

  # This by default removes all CNI plugins and replaces them with nix-defines ones
  # Since we bring our own CNI plugins via containers with host mounts, this causes
  # them to be removed on kubelet restart.
  # TODO(https://github.com/NixOS/nixpkgs/issues/53601): fix when resolved
  systemd.services.kubelet = {
    preStart = pkgs.lib.mkForce ''
      ${lib.concatMapStrings (img: ''
          echo "Seeding container image: ${img}"
          ${
            if (lib.hasSuffix "gz" img)
            then ''${pkgs.gzip}/bin/zcat "${img}" | ${pkgs.containerd}/bin/ctr -n k8s.io image import -''
            else ''${pkgs.coreutils}/bin/cat "${img}" | ${pkgs.containerd}/bin/ctr -n k8s.io image import -''
          }
        '')
        config.services.kubernetes.kubelet.seedDockerImages}
      ${lib.concatMapStrings (package: ''
          echo "Linking cni package: ${package}"
          ln -fs ${package}/bin/* /opt/cni/bin
        '')
        config.services.kubernetes.kubelet.cni.packages}
    '';
  };

  # --- End of section --- #
}
