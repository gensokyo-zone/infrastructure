_: {
  proxmox = {
    vm.id = 105;
    container = {
      enable = true;
      lxc.configJsonFile = ./lxc.json;
    };
    network.interfaces = {
      net0 = {
        macAddress = "BC:24:11:C4:66:A9";
        address4 = "10.1.1.47/24";
        address6 = "auto";
      };
      net1.internal.enable = true;
      net2 = {
        name = "eth1";
        macAddress = "BC:24:11:C4:66:AA";
        networkd.networkSettings.linkConfig.RequiredForOnline = false;
      };
    };
  };
  network.networks = {
    tail = {
      address4 = "100.109.213.94";
      address6 = "fd7a:115c:a1e0::ea01:d55f";
    };
  };
}
