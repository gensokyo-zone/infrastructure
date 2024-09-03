{config, ...}: {
  services.syncthing = {
    enable = true;
    guiAddress = "0.0.0.0:8384";
    openDefaultPorts = true;
    dataDir = "/mnt/kyuuto-litterbox";
  };
  networking.firewall.interfaces = let
    x.allowedTCPPorts = [8384];
  in {
    local = x;
    tail = x;
  };
}
