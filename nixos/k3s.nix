{pkgs, ...}: {
  networking.firewall = {
    allowedTCPPorts = [
      6443
    ];
    allowedUDPPorts = [
    ];
  };

  services.k3s = {
    enable = true;
    role = "server";
    disableAgent = false; # single node server+agent
    extraFlags = toString [
      "--disable=servicelb" # we want to use metallb
      # i guess it's kind of ok to keep the local path provisioner, even though i used to have the yaml files for deploying it on regular k8s
    ];
  };

  environment.systemPackages = [pkgs.k3s];
}
