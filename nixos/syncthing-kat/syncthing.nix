{config, ...}: {
  services.syncthing = {
    enable = true;
    guiAddress = "0.0.0.0:8384";
    openDefaultPorts = true;
    dataDir = "/mnt/kyuuto-litterbox";
  };
  networking.firewall.interfaces.local.allowedTCPPorts = [ 8384 ];
}
