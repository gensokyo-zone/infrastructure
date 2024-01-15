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
    ];
  };

  environment.systemPackages = [pkgs.k3s];
}
